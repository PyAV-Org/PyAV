from collections.abc import Iterator
from fractions import Fraction
from typing import Literal

from av.codec.context import CodecContext
from av.packet import Packet

from .format import VideoFormat
from .frame import VideoFrame

class VideoCodecContext(CodecContext):
    format: VideoFormat | None
    width: int
    height: int
    bits_per_coded_sample: int
    pix_fmt: str | None
    @property
    def sw_format(self) -> VideoFormat | None: ...
    @sw_format.setter
    def sw_format(self, value: str) -> None: ...
    framerate: Fraction
    rate: Fraction
    gop_size: int
    sample_aspect_ratio: Fraction | None
    display_aspect_ratio: Fraction | None
    has_b_frames: bool
    reorder_depth: int
    max_b_frames: int
    coded_width: int
    coded_height: int
    color_range: int
    color_primaries: int
    color_trc: int
    colorspace: int
    qmin: int
    qmax: int
    type: Literal["video"]

    def encode(self, frame: VideoFrame | None = None) -> list[Packet]: ...
    def encode_lazy(self, frame: VideoFrame | None = None) -> Iterator[Packet]: ...
    def decode(self, packet: Packet | None = None) -> list[VideoFrame]: ...
