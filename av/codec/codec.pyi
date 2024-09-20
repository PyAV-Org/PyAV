from fractions import Fraction
from typing import Literal, overload

from av.audio.codeccontext import AudioCodecContext
from av.audio.format import AudioFormat
from av.descriptor import Descriptor
from av.enum import EnumFlag
from av.subtitles.codeccontext import SubtitleCodecContext
from av.video.codeccontext import VideoCodecContext
from av.video.format import VideoFormat

from .context import CodecContext

class Properties(EnumFlag):
    NONE: int
    INTRA_ONLY: int
    LOSSY: int
    LOSSLESS: int
    REORDER: int
    BITMAP_SUB: int
    TEXT_SUB: int

class Capabilities(EnumFlag):
    NONE: int
    DARW_HORIZ_BAND: int
    DR1: int
    HWACCEL: int
    DELAY: int
    SMALL_LAST_FRAME: int
    HWACCEL_VDPAU: int
    SUBFRAMES: int
    EXPERIMENTAL: int
    CHANNEL_CONF: int
    NEG_LINESIZES: int
    FRAME_THREADS: int
    SLICE_THREADS: int
    PARAM_CHANGE: int
    AUTO_THREADS: int
    VARIABLE_FRAME_SIZE: int
    AVOID_PROBING: int
    HARDWARE: int
    HYBRID: int
    ENCODER_REORDERED_OPAQUE: int
    ENCODER_FLUSH: int

class UnknownCodecError(ValueError): ...

class Codec:
    is_encoder: bool
    is_decoder: bool
    descriptor: Descriptor
    name: str
    long_name: str
    type: Literal["video", "audio", "data", "subtitle", "attachment"]
    id: int
    frame_rates: list[Fraction] | None
    audio_rates: list[int] | None
    video_formats: list[VideoFormat] | None
    audio_formats: list[AudioFormat] | None
    properties: Properties
    capabilities: Capabilities
    intra_only: bool
    lossy: bool
    lossless: bool
    reorder: bool
    bitmap_sub: bool
    text_sub: bool
    draw_horiz_band: bool
    dr1: bool
    hwaccel: bool
    delay: bool
    small_last_frame: bool
    hwaccel_vdpau: bool
    subframes: bool
    experimental: bool
    channel_conf: bool
    neg_linesizes: bool
    frame_threads: bool
    slice_threads: bool
    param_change: bool
    auto_threads: bool
    variable_frame_size: bool
    avoid_probing: bool
    hardware: bool
    hybrid: bool
    encoder_reordered_opaque: bool
    encoder_flush: bool

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
