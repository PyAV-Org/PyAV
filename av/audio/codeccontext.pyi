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
    channels: int
    channel_layout: int
    layout: AudioLayout
    format: AudioFormat
    type: Literal["audio"]

    def encode(self, frame: AudioFrame | None = None) -> list[Packet]: ...
    def encode_lazy(self, frame: AudioFrame | None = None) -> Iterator[Packet]: ...
    def decode(self, packet: Packet | None = None) -> list[AudioFrame]: ...
