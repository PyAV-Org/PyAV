from fractions import Fraction
from typing import Any, Iterator, Literal

from av.packet import Packet
from av.stream import Stream

from .codeccontext import VideoCodecContext
from .format import VideoFormat
from .frame import VideoFrame

class VideoStream(Stream):
    bit_rate: int | None
    max_bit_rate: int | None
    bit_rate_tolerance: int
    thread_count: int
    thread_type: Any
    sample_aspect_ratio: Fraction | None
    display_aspect_ratio: Fraction | None
    codec_context: VideoCodecContext
    # from codec context
    format: VideoFormat
    width: int
    height: int
    bits_per_codec_sample: int
    pix_fmt: str | None
    framerate: Fraction
    rate: Fraction
    gop_size: int
    has_b_frames: bool
    coded_width: int
    coded_height: int
    color_range: int
    color_primaries: int
    color_trc: int
    colorspace: int
    type: Literal["video"]

    def encode(self, frame: VideoFrame | None = None) -> list[Packet]: ...
    def encode_lazy(self, frame: VideoFrame | None = None) -> Iterator[Packet]: ...
    def decode(self, packet: Packet | None = None) -> list[VideoFrame]: ...
