from fractions import Fraction
from typing import Any

from av.packet import Packet
from av.stream import Stream

from .codeccontext import VideoCodecContext
from .frame import VideoFrame

class VideoStream(Stream):
    name: str
    width: int
    height: int
    pix_fmt: str | None
    sample_aspect_ratio: Fraction | None
    codec_context: VideoCodecContext

    # from codec context
    bit_rate: int | None
    max_bit_rate: int | None
    bit_rate_tolerance: int
    thread_count: int
    thread_type: Any

    def encode(self, frame: VideoFrame | None = None) -> list[Packet]: ...
    def decode(self, packet: Packet | None = None) -> list[VideoFrame]: ...
