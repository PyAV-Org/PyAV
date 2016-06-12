cimport libav as lib

from av.buffer cimport Buffer
from av.stream cimport Stream


cdef class Packet(Buffer):

    cdef Stream stream
    cdef lib.AVPacket struct

    # Attributes copied from the stream.
    cdef lib.AVRational _time_base

    cdef size_t _buffer_size(self)
    cdef void*  _buffer_ptr(self)
    