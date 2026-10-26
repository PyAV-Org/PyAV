from collections.abc import Iterator
from typing import Any, Literal, final

from typing_extensions import deprecated

from av.codec.codec import Codec
from av.packet import Packet
from av.stream import Stream

from .codeccontext import AudioCodecContext
from .format import AudioFormat
from .frame import AudioFrame
from .layout import AudioLayout

@final
class AudioStream(Stream):
    cctx: AudioCodecContext
    codec_context: AudioCodecContext
    def encode(self, frame: AudioFrame | None = None) -> list[Packet[AudioStream]]: ...
    def encode_lazy(
        self, frame: AudioFrame | None = None
    ) -> Iterator[Packet[AudioStream]]: ...
    def decode(self, packet: Packet[Any] | None = None) -> list[AudioFrame]: ...

    # From codec context
    name: str
    codec: Codec
    codec_tag: str
    options: dict[str, str]
    frame_size: int
    sample_rate: int
    bit_rate: int | None
    max_bit_rate: int | None
    rate: int
    channels: int
    type: Literal["audio"]
    @property
    @deprecated("Use AudioStream.cctx.format instead")
    def format(self) -> AudioFormat | None: ...
    @format.setter
    @deprecated("Use AudioStream.cctx.format instead")
    def format(self, value: AudioFormat | str) -> None: ...
    @property
    @deprecated("Use AudioStream.cctx.layout instead")
    def layout(self) -> AudioLayout: ...
    @layout.setter
    @deprecated("Use AudioStream.cctx.layout instead")
    def layout(self, value: AudioLayout | str) -> None: ...
