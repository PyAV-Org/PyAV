from av.packet cimport Packet
from av.stream cimport Stream


cdef class SubtitleStream(Stream):
    cpdef decode(self, Packet packet=?)
