
cimport libav as lib

cimport av.format
from .utils cimport err_check

cdef class SeekEntry(object):
    def __init__(self):
        pass

cdef class SeekTable(object):
    def __init__(self):
        self.entries = []
        
    cpdef append(self,SeekEntry item):
        self.entries.append(item)


cdef class SeekContext(object):
    def __init__(self,av.format.Context ctx, 
                      av.format.Stream stream, 
                      SeekTable table):
        
        self.ctx = ctx
        self.stream = stream
        self.table = table
    
    cdef flush_buffers(self):
        lib.avcodec_flush_buffers(self.stream.codec.ctx)
        
        
    cdef seek(self, int64_t timestamp, int flags):
        err_check(lib.av_seek_frame(self.ctx.proxy.ptr, self.stream.ptr.index, timestamp,flags))
        self.flush_buffers()
        

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