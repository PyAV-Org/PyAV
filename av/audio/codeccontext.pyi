from typing import Iterator, Literal

from av.codec.context import CodecContext
from av.packet import Packet

from .format import AudioFormat
from .frame import AudioFrame
from .layout import AudioLayout

class AudioCodecContext(CodecContext):
    frame_size: int
    sample_rate: int
    rate: int
    type: Literal["audio"]

    @property
    def format(self) -> AudioFormat: ...
    @format.setter
    def format(self, value: AudioFormat | str) -> None: ...
    @property
    def layout(self) -> AudioLayout: ...
    @layout.setter
    def layout(self, value: AudioLayout | str) -> None: ...
    @property
    def channels(self) -> int: ...
    def encode(self, frame: AudioFrame | None = None) -> list[Packet]: ...
    def encode_lazy(self, frame: AudioFrame | None = None) -> Iterator[Packet]: ...
    def decode(self, packet: Packet | None = None) -> list[AudioFrame]: ...
