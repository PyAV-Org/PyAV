from av.packet cimport Packet
from av.stream cimport Stream

from .frame cimport VideoFrame


cdef class VideoStream(Stream):
    cpdef encode(self, VideoFrame frame=?)
    cpdef decode(self, Packet packet=?)
