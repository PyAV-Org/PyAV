from av.packet cimport Packet
from av.stream cimport Stream


cdef class SubtitleStream(Stream):
    """
    A :class:`SubtitleStream` can contain many :class:`SubtitleSet` objects accessible via decoding.
    """
    def __getattr__(self, name):
        return getattr(self.codec_context, name)

    cpdef decode(self, Packet packet=None):
        """
        Decode a :class:`.Packet` and return a list of :class:`.SubtitleSet`.

        :rtype: list[SubtitleSet]

        .. seealso:: This is a passthrough to :meth:`.CodecContext.decode`.
        """
        if not packet:
            packet = Packet()

        return self.codec_context.decode(packet)
