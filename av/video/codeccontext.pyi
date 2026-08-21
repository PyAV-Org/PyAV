from collections.abc import Iterator
from fractions import Fraction
from typing import Literal

from av.codec.context import CodecContext
from av.packet import Packet
from av.rational import AVRational

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
    @property
    def framerate(self) -> AVRational: ...
    @framerate.setter
    def framerate(self, value: AVRational | Fraction | int) -> None: ...
    @property
    def rate(self) -> AVRational: ...
    @rate.setter
    def rate(self, value: AVRational | Fraction | int) -> None: ...
    gop_size: int
    @property
    def sample_aspect_ratio(self) -> AVRational: ...
    @sample_aspect_ratio.setter
    def sample_aspect_ratio(self, value: AVRational | Fraction | int) -> None: ...
    display_aspect_ratio: AVRational
    has_b_frames: bool
    reorder_depth: int
    max_b_frames: int
    coded_width: int
    coded_height: int
    color_range: int
    color_primaries: int
    color_trc: int
    colorspace: int
    field_order: int
    chroma_sample_location: int
    refs: int
    mb_decision: int
    qmin: int
    qmax: int
    type: Literal["video"]

    def encode(self, frame: VideoFrame | None = None) -> list[Packet]: ...
    def encode_lazy(self, frame: VideoFrame | None = None) -> Iterator[Packet]: ...
    def decode(self, packet: Packet | None = None) -> list[VideoFrame]: ...
