cimport libav as lib

from av.container.core cimport Container
from av.packet cimport Packet
from av.stream cimport Stream


cdef class OutputContainer(Container):
    cdef lib.AVPacket *packet_ptr
    cdef dict _extradata_bsfs
    cdef list[Packet] _buffered_packets
    cdef void _mux_one(self, Packet packet)
    cdef _buffer_for_extradata(self, Packet packet)
    cdef void _try_extract_extradata(self, Packet packet)
    cpdef start_encoding(self)
