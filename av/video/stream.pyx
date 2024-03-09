from av.packet cimport Packet
from .frame cimport VideoFrame

cdef class VideoStream(Stream):
    def __repr__(self):
        return (
            f"<av.VideoStream #{self.index} {self.name}, "
            f"{self.format.name if self.format else None} {self.codec_context.width}x"
            f"{self.codec_context.height} at 0x{id(self):x}>"
        )

    cpdef encode(self, VideoFrame frame=None):
        """
        Encode an :class:`.VideoFrame` and return a list of :class:`.Packet`.

        :return: :class:`list` of :class:`.Packet`.

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
        Decode a :class:`.Packet` and return a list of :class:`.VideoFrame`.
        :return: :class:`list` of :class:`.Frame` subclasses.
        .. seealso:: This is a passthrough to :meth:`.CodecContext.decode`.
        """

        return self.codec_context.decode(packet)
