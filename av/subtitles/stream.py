import cython
from cython.cimports.av.packet import Packet
from cython.cimports.av.stream import Stream


@cython.cclass
class SubtitleStream(Stream):
    def __getattr__(self, name):
        return getattr(self.codec_context, name)

    @cython.ccall
    def decode(self, packet: Packet | None = None):
        """
        Decode a :class:`.Packet` and returns a subtitle object.

        :rtype: list[AssSubtitle] | list[BitmapSubtitle]

        .. seealso:: This is a passthrough to :meth:`.CodecContext.decode`.
        """
        if not packet:
            packet = Packet()

        return self.codec_context.decode(packet)
