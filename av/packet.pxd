cimport libav as lib

from av.buffer cimport Buffer
from av.stream cimport Stream
from av.bytesource cimport ByteSource


cdef class Packet(Buffer):

    # Hold onto the original reference.
    cdef ByteSource source

    cdef Stream stream
    cdef lib.AVPacket struct

    # We hold onto our own time_base because we may become isolated from
    # our parent.
    cdef lib.AVRational _time_base
    cdef int _retime(self, lib.AVRational, lib.AVRational) except -1

    cdef size_t _buffer_size(self)
    cdef void*  _buffer_ptr(self)
    