cimport libav as lib

from av.buffer cimport Buffer
from av.stream cimport Stream
from av.bytesource cimport ByteSource


cdef class Packet(Buffer):

    cdef lib.AVPacket struct
    cdef bint must_free
    
    cdef Stream stream

    # We track our own time.
    cdef lib.AVRational _time_base
    cdef int _retime(self, lib.AVRational, lib.AVRational) except -1

    # Hold onto the original reference.
    cdef ByteSource source
    cdef size_t _buffer_size(self)
    cdef void*  _buffer_ptr(self)
