from av.video.frame cimport VideoFrame
from av.video.format cimport VideoFormatComponent


cdef class VideoPlane(object):
    
    cdef VideoFrame frame
    cdef int index
    cdef VideoFormatComponent component

    # For PEP 3118 buffer protocol.
    cdef Py_ssize_t _buffer_shape[3]
    cdef Py_ssize_t _buffer_strides[3]
    cdef Py_ssize_t _buffer_suboffsets[3]
