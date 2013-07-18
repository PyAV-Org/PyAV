
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
            self.first_packet_dts,
            id(self),
        )

cdef class SeekTable(object):
    def __init__(self):
        self.entries = []
        self.nb_frames = 0
        self.completed = False
        self.nb_entries =0 
        
    cpdef append(self,SeekEntry item):
        self.entries.append(item)
        self.nb_entries += 1
        
    cpdef get_nearest_entry(self,int display_index, int offset=0):
        
        
        cdef SeekEntry entry
        
        if not self.entries:
            raise IndexError("No entries")
        
        
        if display_index < self.entries[0].display_index:
            raise IndexError("Connot find entry before first frame")
        
      
        for i,entry in enumerate(self.entries):
            if entry.display_index > display_index:
                break
        i = i-1
        
        print i
        
        if i < offset:
            raise IndexError("target index out of table range ")
        
        entry = self.entries[i]
        
        entry.first_packet_dts = self.entries[i-offset].first_packet_dts
            
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
        
        self.current_frame_index = FIRST_FRAME_INDEX -1
        self.current_dts = lib.AV_NOPTS_VALUE
        self.previous_dts = lib.AV_NOPTS_VALUE
        self.keyframe_packet_dts = lib.AV_NOPTS_VALUE
        self.first_dts = lib.AV_NOPTS_VALUE
        
    cdef flush_buffers(self):
        lib.avcodec_flush_buffers(self.stream.codec.ctx)
        
        
    cdef seek(self, int64_t timestamp, int flags):
        err_check(lib.av_seek_frame(self.ctx.proxy.ptr, self.stream.ptr.index, timestamp,flags))
        self.flush_buffers()
        
    cpdef forward(self):
        
        if not self.frame_available:
            raise IndexError("No more frames")
        
        self.current_frame_index += 1
        
        cdef av.codec.Packet packet
        cdef SeekEntry entry
        
        while True:

            packet = next(self.ctx.demux([self.stream]))
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
                    entry.first_packet_dts = self.keyframe_packet_dts
                    entry.last_packet_dts = packet.dts
                    
                    if self.get_frame_index() == FIRST_FRAME_INDEX:
                        entry.first_packet_dts = self.first_dts
                        
                    self.table.append(entry)
                    
                    if self.current_frame_index - FIRST_FRAME_INDEX +1 > self.table.nb_frames:
                        self.table.nb_frames = self.current_frame_index - FIRST_FRAME_INDEX +1
                    
                self.frame = frame
                return frame
            else:
                if packet.is_null:
                    self.frame_available = False
                    raise IndexError("No more Frames")
            
    
    def __getitem__(self,x):
        
        self.forward()
        self.forward()
        return self.to_frame(x)
    
                
    def get_frame_index(self):
        
        return self.current_frame_index
    

    
    def to_frame(self, int target_frame):
        
        if target_frame == self.current_frame_index:
            return self.frame
        
        self.to_nearest_keyframe(target_frame)
        
        if self.current_frame_index > target_frame:
            raise IndexError("error advancing to key frame before seek (index isn't right)")
        
        frame = self.frame
        
        while self.current_frame_index < target_frame:
            if self.frame_available:
                frame = self.forward()
            else:
                raise IndexError("error advancing to request frame (probably out of range)")
        
        
    def to_nearest_keyframe(self, int target_frame,int offset = 0):
        
        cdef int flags = 0
        seek_entry = self.table.get_nearest_entry(target_frame)
        
        print "nearst keyframe", seek_entry.display_index
        
        if seek_entry.display_index == self.current_frame_index:
            return self.frame
        
        #// if something goes terribly wrong, return bad current_frame_index
        self.current_frame_index = -2
        self.frame_available = True
        
        
        if seek_entry.first_packet_dts <= self.current_dts:
            flags = lib.AVSEEK_FLAG_BACKWARD

        self.seek(seek_entry.first_packet_dts, flags)

        self.forward()
        
        while self.current_dts < seek_entry.last_packet_dts:
            self.forward()
            
        if self.current_dts != seek_entry.last_packet_dts:
            #seek to last key-frame, but look for this one
            print "missed keyframe, trying previous keyframe"
            print self.current_dts
            print self.table.entries
            raise Exception("what the fuck")
            #self.to_nearest_keyframe(target_frame,  offset + 1)
            
            
        if not self.frame.key_frame and seek_entry.display_index != 0:
            print "found keyframe, but not labeled as keyframe, so trying previous keyframe."
            return self.to_nearest_keyframe(seek_entry.display_index - 1)
        
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