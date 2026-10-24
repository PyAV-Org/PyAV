from collections.abc import Iterator
from typing import Literal

from av.codec.codec import Codec
from av.packet import Packet
from av.stream import Stream

from .codeccontext import AudioCodecContext
from .format import AudioFormat
from .frame import AudioFrame
from .layout import AudioLayout

class _Format:
    def __get__(self, i: object | None, owner: type | None = None) -> AudioFormat: ...
    def __set__(self, instance: object, value: AudioFormat | str) -> None: ...

class _Layout:
    def __get__(self, i: object | None, owner: type | None = None) -> AudioLayout: ...
    def __set__(self, instance: object, value: AudioLayout | str) -> None: ...

class AudioStream(Stream):
    codec_context: AudioCodecContext
    def encode(self, frame: AudioFrame | None = None) -> list[Packet]: ...
    def encode_lazy(self, frame: AudioFrame | None = None) -> Iterator[Packet]: ...
    def decode(self, packet: Packet | None = None) -> list[AudioFrame]: ...

    # From codec context
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
    format: _Format
    layout: _Layout
