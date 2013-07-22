from libc.stdint cimport int64_t
from cpython cimport bool

cimport av.format
cimport av.codec

cdef class SeekEntry(object):
    cdef readonly int display_index
    cdef readonly int64_t first_packet_dts
    cdef readonly int64_t last_packet_dts
    

cdef class SeekTable(object):

    cdef object entries
    cdef object bad_keyframes
    
    cdef reset(self)
    
    cpdef mark_bad_keyframe(self, display_index)
    cpdef append(self, SeekEntry item)
    cpdef get_nearest_entry(self,int display_index, int offset=*)
    
cdef class SeekContext(object):
    cdef SeekTable table
    cdef av.format.Context ctx
    cdef av.format.Stream stream
    cdef av.codec.Codec codec
    
    cdef object frame
    
    #state info
    
    cdef bool active
    cdef bool frame_available
    cdef bool null_packet
    cdef bool seeking
    cdef bool pts_seen
    
    cdef public bool fast_seeking
    cdef public bool sync
    
    cdef readonly int current_frame_index
    
    cdef int64_t current_dts
    cdef int64_t previous_dts
    cdef int64_t keyframe_packet_dts
    cdef int64_t first_dts
    
    cdef flush_buffers(self)
    cdef seek(self, int64_t timestamp, int flags)
    
    cpdef forward(self)

    cpdef frame_to_pts(self, int frame)
    cpdef pts_to_frame(self, int64_t timestamp)
    