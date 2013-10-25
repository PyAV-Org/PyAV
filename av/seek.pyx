from libc.stdint cimport uint8_t, uint16_t, uint32_t, uint64_t, int64_t
cimport libav as lib

cimport av.format

from .utils cimport err_check


FIRST_FRAME_INDEX = 0

class SeekError(ValueError):
    pass

class SeekEnd(SeekError):
    pass
    
cdef class SeekContext(object):
    def __init__(self,av.format.Context ctx, 
                      av.format.Stream stream):
        
        self.ctx = ctx
        self.stream = stream
        self.codec = stream.codec
        
        self.frame = None
        self.nb_frames = 0
        
        self.frame_available =True
        
        self.pts_seen = False
        self.seeking = False
        
        self.current_frame_index = FIRST_FRAME_INDEX -1
        self.current_dts = lib.AV_NOPTS_VALUE
        self.previous_dts = lib.AV_NOPTS_VALUE

    def __repr__(self):
        return '<%s.%s curr_frame: %i curr_dts: %i prev_dts: %i key_dts: %i first_dts: %i at 0x%x>' % (
            self.__class__.__module__,
            self.__class__.__name__,
            self.current_frame_index,
            self.current_dts,
            self.previous_dts,
            self.keyframe_packet_dts,
            self.first_dts,
            id(self),
        )
        
    cdef flush_buffers(self):
        lib.avcodec_flush_buffers(self.codec.ctx)
        
    cdef seek(self, int64_t timestamp, int flags):
        self.flush_buffers()
        err_check(lib.av_seek_frame(self.ctx.proxy.ptr, self.stream.ptr.index, timestamp,flags))
        
    def reset(self):
        self.seek(0,0)
        self.frame =None
        self.current_frame_index = FIRST_FRAME_INDEX -1
        
    cpdef step_forward(self):
        cdef av.codec.Packet packet
                
        cdef av.codec.VideoFrame video_frame
        
        if not self.frame_available:
            raise SeekEnd("No more frames")
        
        self.current_frame_index += 1
        
        #check last frame sync
        if self.frame and not self.seeking:
            pts = self.frame.pts

            if pts != lib.AV_NOPTS_VALUE:
                pts_frame_num = self.ts_to_frame(pts)
                
                if self.current_frame_index -1 < pts_frame_num:
                    #print  "dup frame",self.current_frame_index, "!=",self.ts_to_frame(pts)
                    video_frame = self.frame
                    video_frame.frame_index = self.current_frame_index
                    return video_frame

        while True:

            packet = next(self.ctx.demux([self.stream]))
            
            if packet.struct.pts != lib.AV_NOPTS_VALUE:
                self.pts_seen = True
            
            frame = self.stream.decode(packet)
            if frame:
                
                #check sync to see if we need to drop the frame
                if not self.seeking:
                    pts = frame.pts
                    
                    if pts != lib.AV_NOPTS_VALUE:
                        
                        pts_frame_num = self.ts_to_frame(pts)
                        #print self.current_frame_index,pts_frame_num
                        #allow one frame error mkv off by pts ?!!! 
                        if self.current_frame_index > pts_frame_num + 1:
                            print "need drop frame out of sync", self.current_frame_index, ">",self.ts_to_frame(pts)
                            continue
                            #raise Exception()

                video_frame = frame
                video_frame.frame_index = self.current_frame_index
                    
                self.frame = video_frame
                return video_frame
            else:
                if packet.is_null:
                    self.frame_available = False
                    raise SeekEnd("No more frames")
            
    
    def __getitem__(self,x):

        return self.to_frame(x)
    
    def __len__(self):
        if not self.nb_frames:
            
            if self.stream.frames:
                self.nb_frames = self.stream.frames
            else:
                self.nb_frames = self.get_length_seek()
            
        return self.nb_frames
    
    
    def get_length_seek(self):
        """Get the last frame by seeking to the end of the stream. returns length
        """
        
        cur_frame = self.current_frame_index
        if cur_frame <0:
            cur_frame = 0
        
        cdef lib.AVRational stream_time_base
        
        duration = self.stream.duration
        
        # If the stream doesn't have a duration use duration of av.format.Context
        # and convert it to stream timebase
        
        if duration == lib.AV_NOPTS_VALUE:
            
            ctx_duration = self.ctx.duration
            time_base = self.stream.time_base
            
            stream_time_base.num = time_base.numerator
            stream_time_base.den = time_base.denominator
            
            duration = lib.av_rescale_q(ctx_duration,
                                        lib.AV_TIME_BASE_Q, 
                                        stream_time_base)
        

        last_frame = self.ts_to_frame(duration + self.stream.start_time)
        self.to_nearest_keyframe(last_frame)

        while True:
            try:
                frame = self.step_forward()
            except SeekEnd as e:
                break
            
        length =  self.current_frame_index
        self.to_frame(cur_frame)

        return length

    def to_frame(self, int target_frame):
        
        """Seek to frame and return it
        """
        
        # seek to the nearet keyframe
        self.to_nearest_keyframe(target_frame)
        
        if target_frame == self.current_frame_index:
            return self.frame

        # something went wrong 
        if self.current_frame_index > target_frame:
            self.to_nearest_keyframe(target_frame-1)
            #raise IndexError("error advancing to key frame before seek (index isn't right)")
        
        frame = self.frame
        
        # step step_forward from current frame until we get to the frame
        while self.current_frame_index < target_frame:
            frame = self.step_forward()

        return self.frame
    

    def to_nearest_keyframe(self,int target_frame,offset=0):
        
        """Seek to as close as the target frame as possible without additional frame decoding.
        Sometimes seeking will go too far (current frame > targer_frame), thats what offset is for.
        The offset arg will try seeking too target_frame - offset, while still trying to get the 
        current frame <= target_frame.
        
        """
        
        #optimizations
        if not self.seeking:
            if target_frame == self.current_frame_index:
                return self.frame
            
            if target_frame == self.current_frame_index + 1:
                return self.step_forward()

        if target_frame - offset < 0:
            raise SeekError("cannot seek before first frame")
        
        cdef int flags = 0
        cdef int64_t seek_pts = lib.AV_NOPTS_VALUE
        cdef int64_t current_pts = lib.AV_NOPTS_VALUE
        
        self.seeking = True
        self.frame_available = True
        self.current_frame_index = -2
        
        seek_ts  = self.frame_to_ts(target_frame - offset)
        
        flags = lib.AVSEEK_FLAG_BACKWARD 
        
        self.seek(seek_ts,flags)
        
        retry = 10
        
        # Keep stepping forward until we find a valid pts. Seek should land 
        # on a key frame and the next decoded frame should have a valid pts
        # a retry limit is here just in case so we don't end up decoding every frame.
        
        while current_pts == lib.AV_NOPTS_VALUE:
            frame  = self.step_forward()
            current_pts = frame.pts
            retry -= 1
            if retry < 0:
                raise SeekError("Connnot find keyframe %i %i" % (seek_pts, target_frame) )
            
        current_frame = self.ts_to_frame(current_pts)
        
        #if we seek too far increment the offset and try seeking again  
        if current_frame > target_frame:
            print "seeked too far trying again with offset"
            print  "offset=%i current_frame=%i target_frame=%i seek_target=%i" % (offset, current_frame,target_frame, target_frame- offset)
            return self.to_nearest_keyframe(target_frame, offset + 1)
            
        self.current_frame_index = self.ts_to_frame(current_pts)
        
        cdef av.codec.VideoFrame video_frame
        
        video_frame = self.frame
        video_frame.frame_index = self.current_frame_index

        self.seeking = False
        return video_frame

    cpdef frame_to_ts(self, int frame):
    
        """convert frame number to time stamp using stream time base
        """
        
        fps = self.stream.base_frame_rate
        time_base = self.stream.time_base
        
        cdef int64_t pts
        
        pts = self.stream.start_time + ((frame * fps.denominator * time_base.denominator) \
                                 / (fps.numerator *time_base.numerator))

        return pts
    
    cpdef ts_to_frame(self, int64_t timestamp):
    
        """convert time stamp to frame number using streams time base
        """
        
        if timestamp == lib.AV_NOPTS_VALUE:
            raise Exception("time stamp AV_NOPTS_VALUE")
        
        fps = self.stream.base_frame_rate
        time_base = self.stream.time_base
        
        cdef int64_t frame
        
        frame = ((timestamp - self.stream.start_time) * time_base.numerator * fps.numerator) \
                                      / (time_base.denominator * fps.denominator)
                                      
        return frame