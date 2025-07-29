from fractions import Fraction
from typing import Iterator, Literal

from av.codec.context import ThreadType
from av.packet import Packet
from av.stream import Stream

from .codeccontext import VideoCodecContext
from .format import VideoFormat
from .frame import VideoFrame

class VideoStream(Stream):
    bit_rate: int | None
    max_bit_rate: int | None
    bit_rate_tolerance: int
    sample_aspect_ratio: Fraction | None
    display_aspect_ratio: Fraction | None
    codec_context: VideoCodecContext

    def encode(self, frame: VideoFrame | None = None) -> list[Packet]: ...
    def encode_lazy(self, frame: VideoFrame | None = None) -> Iterator[Packet]: ...
    def decode(self, packet: Packet | None = None) -> list[VideoFrame]: ...

    # from codec context
    format: VideoFormat
    thread_count: int
    thread_type: ThreadType
    width: int
    height: int
    bits_per_coded_sample: int
    pix_fmt: str | None
    framerate: Fraction
    rate: Fraction
    gop_size: int
    has_b_frames: bool
    max_b_frames: int
    coded_width: int
    coded_height: int
    color_range: int
    color_primaries: int
    color_trc: int
    colorspace: int
    type: Literal["video"]
