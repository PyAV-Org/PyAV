cimport libav as lib

from av.packet cimport Packet

cdef class Frame(object):

    cdef lib.AVFrame *ptr
    cdef lib.AVRational time_base

    cdef readonly tuple planes
    cdef _init_planes(self, cls=?)
