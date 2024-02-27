from fractions import Fraction
from typing import Iterator, Literal

from av.codec.context import CodecContext
from av.packet import Packet

from .frame import VideoFrame

class VideoCodecContext(CodecContext):
    width: int
    height: int
    bits_per_codec_sample: int
    pix_fmt: str
    framerate: Fraction
    rate: Fraction
    gop_size: int
    sample_aspect_ratio: Fraction
    display_aspect_ratio: Fraction
    has_b_frames: bool
    coded_width: int
    coded_height: int
    color_range: int
    type: Literal["video"]
    def encode(self, frame: VideoFrame | None = None) -> list[Packet]: ...
    def encode_lazy(self, frame: VideoFrame | None = None) -> Iterator[Packet]: ...
    def decode(self, packet: Packet | None = None) -> list[VideoFrame]: ...
