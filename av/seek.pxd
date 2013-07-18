from libc.stdint cimport int64_t
from cpython cimport bool

cimport av.format

cdef class SeekEntry(object):
    cdef int display_index
    cdef int64_t first_packet_dts
    cdef int64_t last_packet_dts
    

cdef class SeekTable(object):
    cdef bool completed
    cdef int nb_frames
    cdef int nb_entries
    
    cpdef append(self, SeekEntry item)
    
cdef class SeekContext(object):
    cdef SeekTable table
    cdef av.format.Context ctx
    cdef av.format.Stream stream
    
    
    cdef flush_buffers(self)
    cdef seek(self, int64_t timestamp, int flags)

    cpdef frame_to_pts(self, int frame)
    cpdef pts_to_frame(self, int64_t timestamp)
    