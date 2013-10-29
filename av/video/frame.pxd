from libc.stdint cimport uint8_t

cimport libav as lib

from av.frame cimport Frame
from av.video.swscontext cimport SwsContextProxy


cdef class VideoFrame(Frame):

    cdef int buffer_size
    cdef uint8_t *buffer_
    cdef readonly int frame_index
    
    cdef SwsContextProxy sws_proxy
    cpdef reformat(self, int width, int height, char* pix_fmt)
