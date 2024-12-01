from enum import Flag, IntEnum
from fractions import Fraction
from typing import ClassVar, Literal, overload

from av.audio.codeccontext import AudioCodecContext
from av.audio.format import AudioFormat
from av.descriptor import Descriptor
from av.subtitles.codeccontext import SubtitleCodecContext
from av.video.codeccontext import VideoCodecContext
from av.video.format import VideoFormat

from .context import CodecContext

class Properties(Flag):
    NONE: ClassVar[Properties]
    INTRA_ONLY: ClassVar[Properties]
    LOSSY: ClassVar[Properties]
    LOSSLESS: ClassVar[Properties]
    REORDER: ClassVar[Properties]
    BITMAP_SUB: ClassVar[Properties]
    TEXT_SUB: ClassVar[Properties]

class Capabilities(IntEnum):
    none: int
    draw_horiz_band: int
    dr1: int
    hwaccel: int
    delay: int
    small_last_frame: int
    hwaccel_vdpau: int
    subframes: int
    experimental: int
    channel_conf: int
    neg_linesizes: int
    frame_threads: int
    slice_threads: int
    param_change: int
    auto_threads: int
    variable_frame_size: int
    avoid_probing: int
    hardware: int
    hybrid: int
    encoder_reordered_opaque: int
    encoder_flush: int
    encoder_recon_frame: int

class UnknownCodecError(ValueError): ...

class Codec:
    @property
    def is_encoder(self) -> bool: ...
    @property
    def is_decoder(self) -> bool: ...
    descriptor: Descriptor
    @property
    def name(self) -> str: ...
    @property
    def long_name(self) -> str: ...
    @property
    def type(self) -> Literal["video", "audio", "data", "subtitle", "attachment"]: ...
    @property
    def id(self) -> int: ...
    frame_rates: list[Fraction] | None
    audio_rates: list[int] | None
    video_formats: list[VideoFormat] | None
    audio_formats: list[AudioFormat] | None

    @property
    def properties(self) -> int: ...
    @property
    def intra_only(self) -> bool: ...
    @property
    def lossy(self) -> bool: ...
    @property
    def lossless(self) -> bool: ...
    @property
    def reorder(self) -> bool: ...
    @property
    def bitmap_sub(self) -> bool: ...
    @property
    def text_sub(self) -> bool: ...
    @property
    def capabilities(self) -> int: ...
    @property
    def experimental(self) -> bool: ...
    @property
    def delay(self) -> bool: ...
    def __init__(self, name: str, mode: Literal["r", "w"] = "r") -> None: ...
    @overload
    def create(self, kind: Literal["video"]) -> VideoCodecContext: ...
    @overload
    def create(self, kind: Literal["audio"]) -> AudioCodecContext: ...
    @overload
    def create(self, kind: Literal["subtitle"]) -> SubtitleCodecContext: ...
    @overload
    def create(self, kind: None = None) -> CodecContext: ...
    @overload
    def create(
        self, kind: Literal["video", "audio", "subtitle"] | None = None
    ) -> (
        VideoCodecContext | AudioCodecContext | SubtitleCodecContext | CodecContext
    ): ...

class codec_descriptor:
    name: str
    options: tuple[int, ...]

codecs_available: set[str]

def dump_codecs() -> None: ...
