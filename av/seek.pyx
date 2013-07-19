
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
        self.nb_frames = 0
        self.completed = False
        self.nb_entries =0 
        
    cpdef append(self,SeekEntry item):
    
        index =item.display_index
        if index < 0:
            #print "ignore negatived", item
            return
            #raise Exception("negative index")
        self.entries[index] = item
        #self.entries.append(item)
        
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
        entry.first_packet_dts = self.entries[keys[i-offset]].first_packet_dts
                
        return entry
    
cdef class SeekContext(object):
    def __init__(self,av.format.Context ctx, 
                      av.format.Stream stream):
        
        self.ctx = ctx
        self.stream = stream
        self.table = SeekTable()
        self.codec = stream.codec
        
        self.frame = None
        
        self.active = True
        self.frame_available =True
        self.null_packet = False
        self.seeking = False
        
        self.current_frame_index = FIRST_FRAME_INDEX -1
        self.current_dts = lib.AV_NOPTS_VALUE
        self.previous_dts = lib.AV_NOPTS_VALUE
        self.keyframe_packet_dts = lib.AV_NOPTS_VALUE
        self.first_dts = lib.AV_NOPTS_VALUE
        
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
        
        
    cpdef forward(self):
        
        if not self.frame_available:
            raise IndexError("No more frames")
        
        self.current_frame_index += 1
        
        cdef av.codec.Packet packet
        cdef SeekEntry entry
        
        cdef av.codec.VideoFrame video_frame
        #print "**",self.current_frame_index
        while True:

            packet = next(self.ctx.demux([self.stream]))
            #print "packet.dts",packet.dts
            if not packet.is_null:
            
                self.previous_dts = self.current_dts
                
                self.current_dts = packet.dts
            
            #set first dts
            if self.first_dts == lib.AV_NOPTS_VALUE:
                self.first_dts = packet.dts
                
            if packet.struct.flags & lib.AV_PKT_FLAG_KEY:
                #print "keyframe!",self.current_frame_index, packet.pts, packet.dts
                if self.previous_dts == lib.AV_NOPTS_VALUE:
                    self.keyframe_packet_dts = packet.dts
                else:
                    self.keyframe_packet_dts = self.previous_dts
            
            
            frame = self.stream.decode(packet)
            
            if frame:
                
                
                if not packet.is_null and frame.key_frame:
                    entry = SeekEntry()
                    entry.display_index = self.current_frame_index
                    entry.first_packet_dts = frame.first_pkt_dts
                    entry.last_packet_dts = self.current_dts

                    self.table.append(entry)
                    
                video_frame =frame
                video_frame.frame_index = self.current_frame_index
                    
                self.frame = video_frame
                return video_frame
            else:
                if packet.is_null:
                    self.frame_available = False
                    raise IndexError("No more Frames")
            
    
    def __getitem__(self,x):

        return self.to_frame(x)
    
                
    def get_frame_index(self):
        
        return self.current_frame_index
    
    def print_table(self):
        for key, item in sorted(self.table.entries.items()):
            print key, '=',item
            

    
    def to_frame(self, int target_frame):
        
        if target_frame == self.current_frame_index:
            return self.frame
        
        # seek to the nearet keyframe
        self.to_nearest_keyframe(target_frame)
        
        # something went wrong 
        if self.current_frame_index > target_frame:
            raise IndexError("error advancing to key frame before seek (index isn't right)")
        
        frame = self.frame
        
        # step forward from keyframe until we get to the frame
        while self.current_frame_index < target_frame:
            if self.frame_available:
                frame = self.forward()
            else:
                raise IndexError("error advancing to request frame (probably out of range)")
            
        return self.frame
        
        
    def to_nearest_keyframe(self, int target_frame,int offset = 0):
        
        cdef int flags = 0
        
        # first find the nearest known keyframe from the seek table
        # if the seek table to small return the current frame.
        # if there is only one entry in the seek table and the target frame
        # is smaller then the current frame seek to first index which should
        # be the first frame. 
        
        if not self.table.entries:
            return self.frame
        
        if len(self.table.entries) == 1:
            
            if target_frame >= self.current_frame_index:
                return self.frame
            else:
                seek_entry = self.table.entries[0]
        else:
            seek_entry = self.table.get_nearest_entry(target_frame)
            
        # If seek frame is the current frame no need to seek
        if seek_entry.display_index == self.current_frame_index:
            return self.frame
        
        # If something goes terribly wrong, return bad current_frame_index
        self.current_frame_index = -2
        self.frame_available = True
        
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
            #seek to last key-frame, but look for this one
            print "missed keyframe, trying previous keyframe"
            return self.to_nearest_keyframe(target_frame,  offset + 1)
            
            
        if not self.frame.key_frame and seek_entry.display_index != 0:
            print "found keyframe, but not labeled as keyframe, so trying previous keyframe."
            return self.to_nearest_keyframe(seek_entry.display_index - 1)
        
        # Update the current frame
        
        self.current_frame_index = seek_entry.display_index
        
        return self.frame

    cpdef frame_to_pts(self, int frame):
        fps = self.stream.base_frame_rate
        time_base = self.stream.time_base
        cdef int64_t pts
        
        pts = self.stream.start_time + ((frame * fps.denominator * time_base.denominator) \
                                 / (fps.numerator *time_base.numerator))
        return pts
    
    cpdef pts_to_frame(self, int64_t timestamp):
        fps = self.stream.base_frame_rate
        time_base = self.stream.time_base
        
        cdef int frame
        
        frame = ((timestamp - self.start_time) * time_base.numerator * fps.numerator) \
                                      / (time_base.denominator * fps.denominator)
                                      
        return frame