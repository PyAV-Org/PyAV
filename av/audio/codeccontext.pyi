from typing import Iterator, Literal

from av.codec.context import CodecContext
from av.packet import Packet

from .format import AudioFormat
from .frame import AudioFrame
from .layout import AudioLayout

class _Format:
    def __get__(self, i: object | None, owner: type | None = None) -> AudioFormat: ...
    def __set__(self, instance: object, value: AudioFormat | str) -> None: ...

class _Layout:
    def __get__(self, i: object | None, owner: type | None = None) -> AudioLayout: ...
    def __set__(self, instance: object, value: AudioLayout | str) -> None: ...

class AudioCodecContext(CodecContext):
    frame_size: int
    sample_rate: int
    rate: int
    type: Literal["audio"]
    format: _Format
    layout: _Layout
    @property
    def channels(self) -> int: ...
    def encode(self, frame: AudioFrame | None = None) -> list[Packet]: ...
    def encode_lazy(self, frame: AudioFrame | None = None) -> Iterator[Packet]: ...
    def decode(self, packet: Packet | None = None) -> list[AudioFrame]: ...
