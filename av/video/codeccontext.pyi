from fractions import Fraction
from typing import Iterator, Literal

from av.codec.context import CodecContext
from av.packet import Packet

from .format import VideoFormat
from .frame import VideoFrame

class VideoCodecContext(CodecContext):
    format: VideoFormat
    width: int
    height: int
    bits_per_codec_sample: int
    pix_fmt: str | None
    framerate: Fraction
    rate: Fraction
    gop_size: int
    sample_aspect_ratio: Fraction | None
    display_aspect_ratio: Fraction | None
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
