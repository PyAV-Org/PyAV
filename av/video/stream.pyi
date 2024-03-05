from fractions import Fraction
from typing import Any, Literal

from av.packet import Packet
from av.stream import Stream

from .codeccontext import VideoCodecContext
from .format import VideoFormat
from .frame import VideoFrame

class VideoStream(Stream):
    width: int
    height: int
    format: VideoFormat
    pix_fmt: str | None
    sample_aspect_ratio: Fraction | None
    codec_context: VideoCodecContext
    type: Literal["video"]

    # from codec context
    bit_rate: int | None
    max_bit_rate: int | None
    bit_rate_tolerance: int
    thread_count: int
    thread_type: Any

    def encode(self, frame: VideoFrame | None = None) -> list[Packet]: ...  # type: ignore[override]
    def decode(self, packet: Packet | None = None) -> list[VideoFrame]: ...
