from enum import Flag, IntEnum
from fractions import Fraction
from typing import ClassVar, Literal, cast, overload

from av.audio.codeccontext import AudioCodecContext
from av.audio.format import AudioFormat
from av.descriptor import Descriptor
from av.subtitles.codeccontext import SubtitleCodecContext
from av.video.codeccontext import VideoCodecContext
from av.video.format import VideoFormat

from .context import CodecContext

class Properties(Flag):
    NONE = cast(ClassVar[Properties], ...)
    INTRA_ONLY = cast(ClassVar[Properties], ...)
    LOSSY = cast(ClassVar[Properties], ...)
    LOSSLESS = cast(ClassVar[Properties], ...)
    REORDER = cast(ClassVar[Properties], ...)
    BITMAP_SUB = cast(ClassVar[Properties], ...)
    TEXT_SUB = cast(ClassVar[Properties], ...)

class Capabilities(IntEnum):
    none = cast(int, ...)
    draw_horiz_band = cast(int, ...)
    dr1 = cast(int, ...)
    hwaccel = cast(int, ...)
    delay = cast(int, ...)
    small_last_frame = cast(int, ...)
    hwaccel_vdpau = cast(int, ...)
    subframes = cast(int, ...)
    experimental = cast(int, ...)
    channel_conf = cast(int, ...)
    neg_linesizes = cast(int, ...)
    frame_threads = cast(int, ...)
    slice_threads = cast(int, ...)
    param_change = cast(int, ...)
    auto_threads = cast(int, ...)
    variable_frame_size = cast(int, ...)
    avoid_probing = cast(int, ...)
    hardware = cast(int, ...)
    hybrid = cast(int, ...)
    encoder_reordered_opaque = cast(int, ...)
    encoder_flush = cast(int, ...)
    encoder_recon_frame = cast(int, ...)

class UnknownCodecError(ValueError): ...

class Codec:
    @property
    def is_encoder(self) -> bool: ...
    @property
    def is_decoder(self) -> bool: ...
    @property
    def mode(self) -> Literal["r", "w"]: ...
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
def dump_hwconfigs() -> None: ...
