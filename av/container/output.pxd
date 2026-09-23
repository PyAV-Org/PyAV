cimport libav as lib

from av.container.core cimport Container
from av.packet cimport Packet
from av.stream cimport Stream


cdef class OutputContainer(Container):
    cdef lib.AVPacket *packet_ptr
    # How many nogil libav calls are in flight, so close() can refuse
    # to free the context while another thread is still inside one.
    cdef int _blocking_depth
    cdef dict _extradata_bsfs
    cdef list[Packet] _buffered_packets
    cdef _buffer_for_extradata(self, Packet packet)
    cdef void _mux_one(self, Packet packet)
    cdef void _try_extract_extradata(self, Packet packet)
    cpdef start_encoding(self)
