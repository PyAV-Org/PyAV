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
    @property
    def cctx(self) -> AudioCodecContext: ...
    @property
    def codec_context(self) -> AudioCodecContext: ...
    def encode(self, frame: AudioFrame | None = None) -> list[Packet[AudioStream]]: ...
    def encode_lazy(
        self, frame: AudioFrame | None = None
    ) -> Iterator[Packet[AudioStream]]: ...
    def decode(self, packet: Packet[Any] | None = None) -> list[AudioFrame]: ...

    # From codec context
    @property
    def name(self) -> str: ...
    @property
    def codec(self) -> Codec: ...
    codec_tag: str
    options: dict[str, str]
    @property
    def frame_size(self) -> int: ...
    sample_rate: int
    bit_rate: int | None
    max_bit_rate: int | None
    rate: int
    @property
    def channels(self) -> int: ...
    @property
    def type(self) -> Literal["audio"]: ...
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
