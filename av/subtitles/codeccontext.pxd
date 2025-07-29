from av.codec.context cimport CodecContext
from av.packet cimport Packet


cdef class SubtitleCodecContext(CodecContext):
    cpdef decode2(self, Packet packet)
