from av.codec.context cimport CodecContext
from av.packet cimport Packet


cdef class SubtitleCodecContext(CodecContext):
    cdef bint subtitle_header_set
    cpdef decode2(self, Packet packet)
