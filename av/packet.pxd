from cython.cimports.libc.stdint import uint8_t

cimport libav as lib

from av.buffer cimport Buffer
from av.bytesource cimport ByteSource
from av.stream cimport Stream


cdef class PacketSideData:
    cdef uint8_t *data
    cdef size_t size
    cdef lib.AVPacketSideDataType dtype

cdef class Packet(Buffer):
    cdef lib.AVPacket* ptr
    cdef Stream _stream
    cdef _rebase_time(self, lib.AVRational)
    # Hold onto the original reference.
    cdef ByteSource source
    cdef size_t _buffer_size(self)
    cdef void* _buffer_ptr(self)
