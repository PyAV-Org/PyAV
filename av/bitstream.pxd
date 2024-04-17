cimport libav as lib

from av.packet cimport Packet


cdef class BitStreamFilterContext:

    cdef const lib.AVBSFContext *ptr

    cpdef filter(self, Packet packet=?)
    cpdef flush(self)
