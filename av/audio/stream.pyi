from typing import Literal

from av.packet import Packet
from av.stream import Stream

from .codeccontext import AudioCodecContext
from .format import AudioFormat
from .frame import AudioFrame
from .layout import AudioLayout

class AudioStream(Stream):
    codec_context: AudioCodecContext
    # From codec context
    frame_size: int
    sample_rate: int
    bit_rate: int
    rate: int
    channels: int
    type: Literal["audio"]

    @property
    def format(self) -> AudioFormat: ...
    @format.setter
    def format(self, value: AudioFormat | str) -> None: ...
    @property
    def layout(self) -> AudioLayout: ...
    @layout.setter
    def layout(self, value: AudioLayout | str) -> None: ...
    def encode(self, frame: AudioFrame | None = None) -> list[Packet]: ...
    def decode(self, packet: Packet | None = None) -> list[AudioFrame]: ...
