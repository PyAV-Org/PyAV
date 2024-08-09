cimport libav as lib

from av.error cimport err_check
from av.packet cimport Packet


cdef class AttachmentCodecContext(CodecContext):
    pass