from av.packet cimport Packet
from av.stream cimport Stream


cdef class AttachmentStream(Stream):
    """
    An :class:`AttachmentStream`.
    """
    def __getattr__(self, name):
        return getattr(self.codec_context, name)
