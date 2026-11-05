from collections.abc import Iterator, Sequence
from typing import Any, Literal, final

from typing_extensions import deprecated

from av.codec.codec import Codec
from av.codec.context import ThreadType
from av.packet import Packet
from av.rational import AVRational
from av.stream import Stream

from .codeccontext import VideoCodecContext
from .format import VideoFormat
from .frame import VideoFrame

@final
class VideoStream(Stream):
    bit_rate: int | None
    max_bit_rate: int | None
    bit_rate_tolerance: int
    sample_aspect_ratio: AVRational
    @property
    def display_aspect_ratio(self) -> AVRational: ...
    @property
    def cctx(self) -> VideoCodecContext: ...
    @property
    def codec_context(self) -> VideoCodecContext: ...
    def encode(self, frame: VideoFrame | None = None) -> list[Packet[VideoStream]]: ...
    def encode_lazy(
        self, frame: VideoFrame | None = None
    ) -> Iterator[Packet[VideoStream]]: ...
    def decode(self, packet: Packet[Any] | None = None) -> list[VideoFrame]: ...
    def set_display_matrix(self, matrix: Sequence[int] | None) -> None: ...
    def set_display_rotation(
        self, degrees: float, hflip: bool = ..., vflip: bool = ...
    ) -> None: ...
    @property
    def average_rate(self) -> AVRational: ...
    @property
    def base_rate(self) -> AVRational: ...
    @property
    def guessed_rate(self) -> AVRational: ...
    @property
    def codec_rate(self) -> AVRational: ...
    @property
    def video_delay(self) -> int: ...

    # from codec context
    @property
    def name(self) -> str: ...
    @property
    def codec(self) -> Codec: ...
    codec_tag: str
    options: dict[str, str]
    @property
    @deprecated("Use VideoStream.cctx.format instead")
    def format(self) -> VideoFormat | None: ...
    @format.setter
    @deprecated("Use VideoStream.cctx.format instead")
    def format(self, value: VideoFormat) -> None: ...
    @property
    @deprecated("Use VideoStream.cctx.thread_count instead")
    def thread_count(self) -> int: ...
    @thread_count.setter
    @deprecated("Use VideoStream.cctx.thread_count instead")
    def thread_count(self, value: int) -> None: ...
    @property
    @deprecated("Use VideoStream.cctx.thread_type instead")
    def thread_type(self) -> ThreadType: ...
    @thread_type.setter
    @deprecated("Use VideoStream.cctx.thread_type instead")
    def thread_type(self, value: int | str | ThreadType) -> None: ...
    width: int
    height: int
    bits_per_coded_sample: int
    pix_fmt: str | None
    gop_size: int
    @property
    def has_b_frames(self) -> bool: ...
    max_b_frames: int
    @property
    def coded_width(self) -> int: ...
    @property
    def coded_height(self) -> int: ...
    color_range: int
    color_primaries: int
    color_trc: int
    colorspace: int
    chroma_sample_location: int
    @property
    def type(self) -> Literal["video"]: ...
