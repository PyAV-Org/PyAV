from libc.stdint cimport uint8_t, uint16_t, uint32_t, uint64_t, int64_t
cimport libav as lib

cimport av.format
from .utils cimport err_check

FIRST_FRAME_INDEX = 0

cdef class SeekEntry(object):
    def __init__(self):
        pass
        #cdef readonly int display_index
        #cdef readonly int64_t first_packet_dts
        #cdef readonly int64_t last_packet_dts
    
    
    def __repr__(self):
        return '<%s.%s di: %i fp_dts: %i lp_dts: %i at 0x%x>' % (
            self.__class__.__module__,
            self.__class__.__name__,
            self.display_index,
            self.first_packet_dts,
            self.last_packet_dts,
            id(self),
        )

cdef class SeekTable(object):
    def __init__(self):
        self.entries = {}
        self.bad_keyframes = []
        
    cdef reset(self):
        self.entries = {}
        self.bad_keyframes = []
        
    cpdef mark_bad_keyframe(self,display_index):
        self.bad_keyframes.append(display_index)
        
    cpdef append(self,SeekEntry item):
    
        index =item.display_index
        if index < 0:
            #print "ignore negatived", item
            return
        
        if index in self.bad_keyframes:
            return
        
        self.entries[index] = item

    cpdef get_nearest_entry(self,int display_index, int offset=0):
        
        
        cdef SeekEntry entry
        
        if not self.entries:
            raise IndexError("No entries")
        
        
        keys = sorted(self.entries.keys())
        
        if display_index < self.entries[keys[0]].display_index:
            raise IndexError("tried to seek to frame index before first frame")
        
        for i, key in enumerate(keys):
            if key > display_index:
                break
            
        #pick the index before
        i = i -1
        
        if i < offset:
            raise IndexError("target index out of table range (too small)")
        
        entry = self.entries[keys[i]]
        if offset:
            print "using offset"
            #entry = self.entries[keys[i-offset]]
            entry = self.entries[keys[i-offset]]
                
        return entry
    
cdef class SeekContext(object):
    def __init__(self,av.format.Context ctx, 
                      av.format.Stream stream):
        
        self.ctx = ctx
        self.stream = stream
        self.table = SeekTable()
        self.codec = stream.codec
        
        self.frame = None
        
        self.frame_available =True
        
        self.pts_seen = False
        self.seeking = False
        self.fast_seeking = True
        self.sync = True
        
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
        self.table.reset()
        self.seek(0,0)
        self.frame =None
        self.current_frame_index = FIRST_FRAME_INDEX -1
        
    cpdef forward(self):
        cdef av.codec.Packet packet
        cdef SeekEntry entry
        
        cdef av.codec.VideoFrame video_frame
        
        if not self.frame_available:
            raise IndexError("No more frames")
        
        self.current_frame_index += 1
        
        #check last frame sync
        if self.sync and self.frame and not self.seeking:
            pts = self.frame.first_pkt_pts

            if pts != lib.AV_NOPTS_VALUE:
                pts_frame_num = self.pts_to_frame(pts)
                
                if self.current_frame_index -1 < pts_frame_num:
                    #print  "dup frame",self.current_frame_index, "!=",self.pts_to_frame(pts)
                    video_frame = self.frame
                    video_frame.frame_index = self.current_frame_index
                    return video_frame

        while True:
            
            
            packet = next(self.ctx.demux([self.stream]))
            
            if packet.struct.pts != lib.AV_NOPTS_VALUE:
                self.pts_seen = True
            
            #print count, 'dts', packet.struct.dts

            #print "packet.dts",packet.dts
            #if not packet.is_null:
        
            self.previous_dts = self.current_dts
            self.current_dts = packet.struct.dts
                
            frame = self.stream.decode(packet)
            if frame:
                
                #check sync to see if we need to drop the frame
                if self.sync and not self.seeking:
                    pts = frame.first_pkt_pts
                    #if not self.pts_seen:
                        #pts = frame.first_pkt_dts
                        
                    if pts != lib.AV_NOPTS_VALUE:
                        pts_frame_num = self.pts_to_frame(pts)
                        
                        if self.current_frame_index > pts_frame_num:
                            print "need drop frame out of sync", self.current_frame_index, ">",self.pts_to_frame(pts)
                            continue
                            #raise Exception()
                        
                if frame.key_frame and not self.seeking and not packet.is_null:
                    entry = SeekEntry()
                    entry.display_index = self.current_frame_index
                    entry.first_packet_dts = frame.last_pkt_dts
                    entry.last_packet_dts = frame.last_pkt_dts
                    self.table.append(entry)
                    
                video_frame =frame
                video_frame.frame_index = self.current_frame_index
                    
                self.frame = video_frame
                return video_frame
            else:
                if packet.is_null:
                    self.frame_available = False
                    self.seek(0,0)
                    self.current_frame_index = FIRST_FRAME_INDEX -1
                    self.forward()
                    raise IndexError("No more Frames")
            
    
    def __getitem__(self,x):

        return self.to_frame(x)
    
    def __len__(self):
        return self.stream.frames
    
                
    def get_frame_index(self):
        
        return self.current_frame_index
    
    def print_table(self):
        for key, item in sorted(self.table.entries.items()):
            print key, '=',item
            

    
    def to_frame(self, int target_frame):
        
        # seek to the nearet keyframe
        
        self.to_nearest_keyframe(target_frame)
        
        if target_frame == self.current_frame_index:
            return self.frame

        # something went wrong 
        if self.current_frame_index > target_frame:
            self.to_nearest_keyframe(target_frame-1)
            #raise IndexError("error advancing to key frame before seek (index isn't right)")
        
        frame = self.frame
        
        # step forward from keyframe until we get to the frame
        while self.current_frame_index < target_frame:
            if self.frame_available:
                frame = self.forward()
            else:
                raise IndexError("error advancing to request frame (probably out of range)")
            
        return self.frame
    
    def to_nearest_keyframe(self,int target_frame):
        
        #fast seeking doesn't work properly if 
        if self.fast_seeking and self.sync:
            self.to_nearest_keyframe_fast(target_frame)
        else:
            self.to_nearest_keyframe_slow(target_frame)
        
    def to_nearest_keyframe_slow(self, int target_frame,int offset = 0):
        
        cdef int flags = 0
        
        # first find the nearest known keyframe from the seek table
        # if the seek table to small return the current frame.
        # if there is only one entry in the seek table and the target frame
        # is smaller then the current frame seek to first index which should
        # be the first frame. 
        
        if not self.table.entries:
            return self.forward()
        
        if len(self.table.entries) == 1:
            if target_frame >= self.current_frame_index:
                return self.frame
            else:
                seek_entry = self.table.entries.values()[0]
                print "using first entry", seek_entry
        else:
            seek_entry = self.table.get_nearest_entry(target_frame)
        
        if not self.seeking:
            #optimizations
            if target_frame == self.current_frame_index:
                return self.frame
            
            if target_frame == self.current_frame_index +1:
                return self.forward()
            
            # If seek frame is the current frame no need to seek
            if seek_entry.display_index == self.current_frame_index:
                return self.frame
        
        # If something goes terribly wrong, return bad current_frame_index
        self.current_frame_index = -2
        self.frame_available = True
        self.seeking = True
        
        # If the seek frame is less then the current frame we need to seek backwards
        if seek_entry.first_packet_dts <= self.current_dts:
            flags = 0
            flags = lib.AVSEEK_FLAG_BACKWARD 
        
        # Seek
        self.seek(seek_entry.first_packet_dts, flags)
        # Move forward to get frame info
        self.forward()
        
        # Keep moving till we hit the keyframe
        while self.current_dts < seek_entry.last_packet_dts:
            self.forward()


        if self.current_dts != seek_entry.last_packet_dts:
            #remove bad entry and try again
            print "bad keyframe, removing bad entry, trying previous keyframe"
            del self.table.entries[seek_entry.display_index]
            self.table.mark_bad_keyframe(seek_entry.display_index)
            return self.to_nearest_keyframe_slow(seek_entry.display_index)
            
            
        if not self.frame.key_frame and seek_entry.display_index != 0:
            #remove bad entry and try again
            print "not on a keyframe, removing bad entry,trying previous keyframe"
            del self.table.entries[seek_entry.display_index]
            self.table.mark_bad_keyframe(seek_entry.display_index)
            return self.to_nearest_keyframe_slow(seek_entry.display_index)
        
        # Update the current frame and make sure frame_index of frame is correct
        cdef av.codec.VideoFrame video_frame
        self.current_frame_index = seek_entry.display_index
        self.seeking = False
        
        video_frame = self.frame
        video_frame.frame_index = self.current_frame_index
        
        return video_frame
    
    def to_nearest_keyframe_fast(self,int target_frame):
        
        if not self.table.entries:
            self.forward()
        
        #optimizations
        if not self.seeking:
            if target_frame == self.current_frame_index:
                return self.frame
            
            if target_frame == self.current_frame_index + 1:
                return self.forward()

        cdef int flags = 0
        cdef int64_t target_pts = lib.AV_NOPTS_VALUE
        cdef int64_t current_pts = lib.AV_NOPTS_VALUE
        self.seeking = True
        
        target_pts  = self.frame_to_pts(target_frame)
        
        flags = lib.AVSEEK_FLAG_BACKWARD 
        
        self.seek(target_pts,flags)
        
        retry = 10
        while current_pts == lib.AV_NOPTS_VALUE:
            frame  = self.forward()
            
            if frame.key_frame:
                current_pts = frame.first_pkt_pts
                #print "first_pts", current_pts,"first_dts",frame.first_pkt_dts,"last_dts", frame.last_pkt_dts,"last_pts",frame.last_pkt_pts
                if current_pts == lib.AV_NOPTS_VALUE and not self.pts_seen:
                    print 'using dts'
                    current_pts = frame.first_pkt_dts
            retry -= 1
            #print frame.first_pkt_dts, self.current_dts,frame.key_frame
            if retry < 0:
                break
            
            
        if retry < 0:
            print "giving up using slow seek"
            print 'target',target_frame
            print frame.first_pkt_pts,frame.first_pkt_dts
            raise Exception()
            self.fast_seeking = False
            self.reset()
            return self.to_nearest_keyframe(target_frame)
            
        if current_pts > target_pts:
            print "went to far", current_pts,target_pts
            return self.to_nearest_keyframe_fast(target_frame-1)
            
        self.current_frame_index = self.pts_to_frame(current_pts)
        
        cdef av.codec.VideoFrame video_frame
        
        video_frame = self.frame
        video_frame.frame_index = self.current_frame_index

        #this is just for debuging doesn't put valid dts 
        if video_frame.key_frame:
            entry = SeekEntry()
            entry.display_index = self.current_frame_index
            entry.first_packet_dts = video_frame.first_pkt_dts
            entry.last_packet_dts = self.current_dts
            #print "*", entry
            self.table.append(entry)

        self.seeking = False
        return video_frame
    

    cpdef frame_to_pts(self, int frame):
        fps = self.stream.base_frame_rate
        time_base = self.stream.time_base
        cdef int64_t pts
        
        pts = self.stream.start_time + ((frame * fps.denominator * time_base.denominator) \
                                 / (fps.numerator *time_base.numerator))
        return pts
    
    cpdef pts_to_frame(self, int64_t timestamp):
        
        if timestamp == lib.AV_NOPTS_VALUE:
            raise Exception("time stamp AV_NOPTS_VALUE")
        
        fps = self.stream.base_frame_rate
        time_base = self.stream.time_base
        
        cdef int64_t frame
        
        frame = ((timestamp - self.stream.start_time) * time_base.numerator * fps.numerator) \
                                      / (time_base.denominator * fps.denominator)
                                      
        return frame