cimport libav as lib

from av.packet cimport Packet


cdef class BitStreamFilterContext:

    cdef lib.AVBSFContext *ptr

    cpdef filter(self, Packet packet=?)
    cpdef flush(self)
