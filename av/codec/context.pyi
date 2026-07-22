from dataclasses import dataclass
from enum import Flag, IntEnum, IntFlag
from fractions import Fraction
from typing import ClassVar, Literal, cast, overload

from av.audio import _AudioCodecName
from av.audio.codeccontext import AudioCodecContext
from av.packet import Packet
from av.subtitles import _SubtitleCodecName
from av.subtitles.codeccontext import SubtitleCodecContext
from av.video import _VideoCodecName
from av.video.codeccontext import VideoCodecContext

from .codec import Codec
from .hwaccel import HWAccel

class ThreadType(Flag):
    NONE = cast(ClassVar[ThreadType], ...)
    FRAME = cast(ClassVar[ThreadType], ...)
    SLICE = cast(ClassVar[ThreadType], ...)
    AUTO = cast(ClassVar[ThreadType], ...)
    def __get__(self, i: object | None, owner: type | None = None) -> ThreadType: ...
    def __set__(self, instance: object, value: int | str | ThreadType) -> None: ...

class Flags(IntEnum):
    unaligned = cast(int, ...)
    qscale = cast(int, ...)
    four_mv = cast(int, ...)
    output_corrupt = cast(int, ...)
    qpel = cast(int, ...)
    recon_frame = cast(int, ...)
    copy_opaque = cast(int, ...)
    frame_duration = cast(int, ...)
    pass1 = cast(int, ...)
    pass2 = cast(int, ...)
    loop_filter = cast(int, ...)
    gray = cast(int, ...)
    psnr = cast(int, ...)
    interlaced_dct = cast(int, ...)
    low_delay = cast(int, ...)
    global_header = cast(int, ...)
    bitexact = cast(int, ...)
    ac_pred = cast(int, ...)
    interlaced_me = cast(int, ...)
    closed_gop = cast(int, ...)

class Flags2(IntEnum):
    fast = cast(int, ...)
    no_output = cast(int, ...)
    local_header = cast(int, ...)
    chunks = cast(int, ...)
    ignore_crop = cast(int, ...)
    show_all = cast(int, ...)
    export_mvs = cast(int, ...)
    skip_manual = cast(int, ...)
    ro_flush_noop = cast(int, ...)

class OptionType(IntEnum):
    FLAGS = cast(int, ...)
    INT = cast(int, ...)
    INT64 = cast(int, ...)
    DOUBLE = cast(int, ...)
    FLOAT = cast(int, ...)
    STRING = cast(int, ...)
    RATIONAL = cast(int, ...)
    BINARY = cast(int, ...)
    DICT = cast(int, ...)
    UINT64 = cast(int, ...)
    CONST = cast(int, ...)
    IMAGE_SIZE = cast(int, ...)
    PIXEL_FMT = cast(int, ...)
    SAMPLE_FMT = cast(int, ...)
    VIDEO_RATE = cast(int, ...)
    DURATION = cast(int, ...)
    COLOR = cast(int, ...)
    CHANNEL_LAYOUT = cast(int, ...)
    BOOL = cast(int, ...)
    UINT = cast(int, ...)

class OptionFlags(IntFlag):
    ENCODING_PARAM = cast(int, ...)
    DECODING_PARAM = cast(int, ...)
    AUDIO_PARAM = cast(int, ...)
    VIDEO_PARAM = cast(int, ...)
    SUBTITLE_PARAM = cast(int, ...)
    EXPORT = cast(int, ...)
    READONLY = cast(int, ...)
    BITSTREAM_FILTER_PARAM = cast(int, ...)
    RUNTIME_PARAM = cast(int, ...)
    FILTERING_PARAM = cast(int, ...)
    DEPRECATED = cast(int, ...)
    CHILD_CONSTS = cast(int, ...)

@dataclass(frozen=True, slots=True)
class CodecOptionChoice:
    name: str
    help: str

@dataclass(frozen=True, slots=True)
class CodecOption:
    name: str
    help: str
    type: OptionType | int
    is_array: bool
    default: str | None
    min: float
    max: float
    flags: OptionFlags
    choices: tuple[CodecOptionChoice, ...]

@dataclass(frozen=True, slots=True)
class CodecOptionSet:
    generic: tuple[CodecOption, ...]
    private: tuple[CodecOption, ...]

class CodecContext:
    name: str
    type: Literal["video", "audio", "data", "subtitle", "attachment"]
    options: dict[str, str]
    @property
    def supported_options(self) -> CodecOptionSet: ...
    profile: str | None
    level: int
    @property
    def profiles(self) -> list[str]: ...
    extradata: bytes | None
    time_base: Fraction
    codec_tag: str
    global_quality: int
    bit_rate: int | None
    bit_rate_tolerance: int
    thread_count: int
    thread_type: ThreadType
    skip_frame: Literal[
        "NONE", "DEFAULT", "NONREF", "BIDIR", "NONINTRA", "NONKEY", "ALL"
    ]
    flags: int
    qscale: bool
    copy_opaque: bool
    flags2: int
    @property
    def is_open(self) -> bool: ...
    @property
    def is_encoder(self) -> bool: ...
    @property
    def is_decoder(self) -> bool: ...
    @property
    def codec(self) -> Codec: ...
    @property
    def max_bit_rate(self) -> int | None: ...
    @property
    def delay(self) -> bool: ...
    @property
    def extradata_size(self) -> int: ...
    @property
    def is_hwaccel(self) -> bool: ...
    def open(self, strict: bool = True) -> None: ...
    @overload
    @staticmethod
    def create(
        codec: _AudioCodecName,
        mode: Literal["r", "w"] | None = None,
        hwaccel: HWAccel | None = None,
    ) -> AudioCodecContext: ...
    @overload
    @staticmethod
    def create(
        codec: _VideoCodecName,
        mode: Literal["r", "w"] | None = None,
        hwaccel: HWAccel | None = None,
    ) -> VideoCodecContext: ...
    @overload
    @staticmethod
    def create(
        codec: _SubtitleCodecName,
        mode: Literal["r", "w"] | None = None,
        hwaccel: HWAccel | None = None,
    ) -> SubtitleCodecContext: ...
    @overload
    @staticmethod
    def create(
        codec: str | Codec,
        mode: Literal["r", "w"] | None = None,
        hwaccel: HWAccel | None = None,
    ) -> CodecContext: ...
    def parse(
        self, raw_input: bytes | bytearray | memoryview | None = None
    ) -> list[Packet]: ...
    def flush_buffers(self) -> None: ...
