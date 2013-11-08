from libc.stdint cimport uint8_t

cimport libav as lib

from av.frame cimport Frame
from av.video.swscontext cimport SwsContextProxy
from av.video.format cimport VideoFormat


cdef class VideoFrame(Frame):
    
    # This is the buffer that is used to back everything in the AVPicture.
    # We don't ever actually access it directly.
    cdef uint8_t *_buffer
    cdef readonly int buffer_size

    cdef readonly int frame_index
    cdef SwsContextProxy sws_proxy

    cdef readonly VideoFormat format
    cdef _init(self, lib.AVPixelFormat format, unsigned int width, unsigned int height)
    cpdef reformat(self, int width, int height, char* format)

    # PEP 3118 buffer protocol.
    cdef Py_ssize_t _buffer_shape[3]
    cdef Py_ssize_t _buffer_strides[3]
    cdef Py_ssize_t _buffer_suboffsets[3]

cdef VideoFrame blank_video_frame()
