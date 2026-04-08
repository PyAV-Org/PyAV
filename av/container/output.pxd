cimport libav as lib

from av.container.core cimport Container
from av.stream cimport Stream


cdef class OutputContainer(Container):
    cdef lib.AVPacket *packet_ptr
    cpdef start_encoding(self)
