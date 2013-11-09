from libc.stdint cimport uint8_t

cimport libav as lib

from av.frame cimport Frame
from av.video.swscontext cimport SwsContextProxy
from av.video.format cimport VideoFormat


cdef class VideoFrame(Frame):
    
    # This is the buffer that is used to back everything in the AVPicture.
    # We don't ever actually access it directly.
    cdef uint8_t *_buffer

    cdef readonly int frame_index
    cdef SwsContextProxy sws_proxy

    cdef readonly VideoFormat format

    cdef _init(self, lib.AVPixelFormat format, unsigned int width, unsigned int height)
    cdef _init_properties(self)

    cpdef reformat(self, int width, int height, char* format)


cdef VideoFrame blank_video_frame()
