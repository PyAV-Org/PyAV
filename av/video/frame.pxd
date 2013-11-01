from libc.stdint cimport uint8_t

cimport libav as lib

from av.frame cimport Frame
from av.video.swscontext cimport SwsContextProxy


cdef class VideoFrame(Frame):
    
    # This is the buffer that is used to back everything in the AVPicture.
    # We don't ever actually access it directly.
    cdef uint8_t *_buffer
    cdef readonly int buffer_size

    cdef readonly int frame_index
    cdef SwsContextProxy sws_proxy

    cdef _init(self, unsigned int width, unsigned int height, lib.AVPixelFormat format)
    cpdef reformat(self, int width, int height, char* format)
