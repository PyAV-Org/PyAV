cimport libav as lib

from av.container.core cimport Container
from av.stream cimport Stream


cdef class OutputContainer(Container):
    cdef bint _started
    cdef bint _done
    cdef bint _avio_opened
    cdef lib.AVPacket *packet_ptr

    cpdef start_encoding(self)
