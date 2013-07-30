from libc.stdint cimport int64_t
from cpython cimport bool

cimport av.format
cimport av.codec
    
cdef class SeekContext(object):

    cdef av.format.Context ctx
    cdef av.format.Stream stream
    cdef av.codec.Codec codec
    
    cdef object frame
    
    #state info

    cdef bool frame_available
    cdef bool seeking
    cdef bool pts_seen
    cdef int nb_frames
        
    cdef readonly int current_frame_index
    
    cdef int64_t current_dts
    cdef int64_t previous_dts
    
    cdef flush_buffers(self)
    cdef seek(self, int64_t timestamp, int flags)
    
    cpdef step_forward(self)

    cpdef frame_to_ts(self, int frame)
    cpdef ts_to_frame(self, int64_t timestamp)
    