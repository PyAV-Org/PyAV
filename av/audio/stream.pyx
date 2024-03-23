from av.packet cimport Packet

from .frame cimport AudioFrame


cdef class AudioStream(Stream):
    def __repr__(self):
        form = self.format.name if self.format else None
        return (
            f"<av.AudioStream #{self.index} {self.name} at {self.rate}Hz,"
            f" {self.layout.name}, {form} at 0x{id(self):x}>"
        )

    def __getattr__(self, name):
        return getattr(self.codec_context, name)

    cpdef encode(self, AudioFrame frame=None):
        """
        Encode an :class:`.AudioFrame` and return a list of :class:`.Packet`.

        :rtype: list[Packet]

        .. seealso:: This is mostly a passthrough to :meth:`.CodecContext.encode`.
        """

        packets = self.codec_context.encode(frame)
        cdef Packet packet
        for packet in packets:
            packet._stream = self
            packet.ptr.stream_index = self.ptr.index

        return packets

    cpdef decode(self, Packet packet=None):
        """
        Decode a :class:`.Packet` and return a list of :class:`.AudioFrame`.

        :rtype: list[AudioFrame]

        .. seealso:: This is a passthrough to :meth:`.CodecContext.decode`.
        """

        return self.codec_context.decode(packet)
