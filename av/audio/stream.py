import warnings

import cython
from cython.cimports import libav as lib
from cython.cimports.av.audio.frame import AudioFrame
from cython.cimports.av.packet import Packet


def _warn_passthrough(name):
    warnings.warn(
        f"AudioStream.{name} is deprecated; use AudioStream.cctx.{name} instead",
        DeprecationWarning,
        # Cython functions have no frames, so 1 is the caller.
        stacklevel=1,
    )


@cython.final
@cython.cclass
class AudioStream(Stream):
    def __repr__(self):
        if not self._is_open():
            return (
                f"<av.{self.__class__.__name__} (container closed) at 0x{id(self):x}>"
            )

        if self.cctx is None:
            return f"<av.AudioStream #{self.index} audio/<nocodec> at 0x{id(self):x}>"
        cc = self.cctx
        form = cc.format.name if cc.format else None
        return (
            f"<av.AudioStream #{self.index} {self.name} at {self.rate}Hz,"
            f" {cc.layout.name}, {form} at 0x{id(self):x}>"
        )

    def __getattr__(self, name):
        if self.cctx is None:
            raise AttributeError(
                f"'{type(self).__name__}' object has no attribute '{name}'"
            )
        return getattr(self.cctx, name)

    @property
    def format(self):
        """
        The audio sample format of the codec context.

        .. deprecated:: 19.1
            Use ``stream.cctx.format`` instead.

        :type: AudioFormat | None
        """
        _warn_passthrough("format")
        if self.cctx is None:
            raise AttributeError(
                f"'{type(self).__name__}' object has no attribute 'format'"
            )
        return self.cctx.format

    @format.setter
    def format(self, value):
        _warn_passthrough("format")
        if self.cctx is not None:
            self.cctx.format = value

    @property
    def layout(self):
        """
        The audio channel layout of the codec context.

        .. deprecated:: 19.1
            Use ``stream.cctx.layout`` instead.

        :type: AudioLayout
        """
        _warn_passthrough("layout")
        if self.cctx is None:
            raise AttributeError(
                f"'{type(self).__name__}' object has no attribute 'layout'"
            )
        return self.cctx.layout

    @layout.setter
    def layout(self, value):
        _warn_passthrough("layout")
        if self.cctx is not None:
            self.cctx.layout = value

    @cython.ccall
    def encode(self, frame: AudioFrame | None = None):
        """
        Encode an :class:`.AudioFrame` and return a list of :class:`.Packet`.

        :rtype: list[Packet]

        .. seealso:: This is mostly a passthrough to :meth:`.CodecContext.encode`.
        """
        self._assert_has_codec_context(lib.AVERROR_ENCODER_NOT_FOUND)
        packets = self.cctx.encode(frame)
        packet: Packet
        for packet in packets:
            packet._stream = self
            packet.ptr.stream_index = self.ptr.index

        return packets

    def encode_lazy(self, frame: AudioFrame | None = None):
        """
        Encode an :class:`.AudioFrame` and yield each :class:`.Packet` as it is produced.

        .. seealso:: This is mostly a passthrough to :meth:`.CodecContext.encode_lazy`.
        """
        self._assert_has_codec_context(lib.AVERROR_ENCODER_NOT_FOUND)
        packet: Packet
        for packet in self.cctx.encode_lazy(frame):
            packet._stream = self
            packet.ptr.stream_index = self.ptr.index
            yield packet

    @cython.ccall
    def decode(self, packet: Packet | None = None):
        """
        Decode a :class:`.Packet` and return a list of :class:`.AudioFrame`.

        :rtype: list[AudioFrame]

        .. seealso:: This is a passthrough to :meth:`.CodecContext.decode`.
        """
        self._assert_has_codec_context()
        return self.cctx.decode(packet)
