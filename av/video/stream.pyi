from collections.abc import Iterator, Sequence
from typing import Literal

from av.codec.codec import Codec
from av.codec.context import ThreadType
from av.packet import Packet
from av.rational import AVRational
from av.stream import Stream

from .codeccontext import VideoCodecContext
from .format import VideoFormat
from .frame import VideoFrame

class VideoStream(Stream):
    bit_rate: int | None
    max_bit_rate: int | None
    bit_rate_tolerance: int
    sample_aspect_ratio: AVRational
    display_aspect_ratio: AVRational
    codec_context: VideoCodecContext

    def encode(self, frame: VideoFrame | None = None) -> list[Packet]: ...
    def encode_lazy(self, frame: VideoFrame | None = None) -> Iterator[Packet]: ...
    def decode(self, packet: Packet | None = None) -> list[VideoFrame]: ...
    def set_display_matrix(self, matrix: Sequence[int] | None) -> None: ...
    def set_display_rotation(
        self, degrees: float, hflip: bool = ..., vflip: bool = ...
    ) -> None: ...

    average_rate: AVRational
    base_rate: AVRational
    guessed_rate: AVRational

    # from codec context
    codec: Codec
    codec_tag: str
    options: dict[str, str]
    format: VideoFormat
    thread_count: int
    @property
    def thread_type(self) -> ThreadType: ...
    @thread_type.setter
    def thread_type(self, value: int | str | ThreadType) -> None: ...
    width: int
    height: int
    bits_per_coded_sample: int
    pix_fmt: str | None
    gop_size: int
    has_b_frames: bool
    max_b_frames: int
    coded_width: int
    coded_height: int
    color_range: int
    color_primaries: int
    color_trc: int
    colorspace: int
    chroma_sample_location: int
    type: Literal["video"]
