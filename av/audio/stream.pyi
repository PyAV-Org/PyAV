from typing import Literal

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
    # From codec context
    frame_size: int
    sample_rate: int
    bit_rate: int
    rate: int
    channels: int
    type: Literal["audio"]
    format: _Format
    layout: _Layout
    def encode(self, frame: AudioFrame | None = None) -> list[Packet]: ...
    def decode(self, packet: Packet | None = None) -> list[AudioFrame]: ...
