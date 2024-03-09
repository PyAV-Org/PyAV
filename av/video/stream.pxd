from av.stream cimport Stream
from .frame cimport VideoFrame
from av.packet cimport Packet


cdef class VideoStream(Stream):
    cpdef encode(self, VideoFrame frame=?)
    cpdef decode(self, Packet packet=?)
