from fractions import Fraction
from typing import Any, Literal

from av.enum import EnumFlag, EnumItem
from av.packet import Packet

from .codec import Codec

class ThreadType(EnumFlag):
    NONE: int
    FRAME: int
    SLICE: int
    AUTO: int

class SkipType(EnumItem):
    NONE: int
    DEFAULT: int
    NONREF: int
    BIDIR: int
    NONINTRA: int
    NONKEY: int
    ALL: int

class Flags(EnumFlag):
    NONE: int
    UNALIGNED: int
    QSCALE: int
    # 4MV
    OUTPUT_CORRUPT: int
    QPEL: int
    DROPCHANGED: int
    PASS1: int
    PASS2: int
    LOOP_FILTER: int
    GRAY: int
    PSNR: int
    INTERLACED_DCT: int
    LOW_DELAY: int
    GLOBAL_HEADER: int
    BITEXACT: int
    AC_PRED: int
    INTERLACED_ME: int
    CLOSED_GOP: int

class Flags2(EnumFlag):
    NONE: int
    FAST: int
    NO_OUTPUT: int
    LOCAL_HEADER: int
    CHUNKS: int
    IGNORE_CROP: int
    SHOW_ALL: int
    EXPORT_MVS: int
    SKIP_MANUAL: int
    RO_FLUSH_NOOP: int

class CodecContext:
    name: str
    type: Literal["video", "audio", "data", "subtitle", "attachment"]
    options: dict[str, str]
    profile: str | None
    extradata: bytes | None
    time_base: Fraction
    codec_tag: str
    bit_rate: int | None
    bit_rate_tolerance: int
    thread_count: int
    thread_type: Any
    skip_frame: Any

    # flags
    unaligned: bool
    qscale: bool
    four_mv: bool
    output_corrupt: bool
    qpel: bool
    drop_changed: bool
    recon_frame: bool
    copy_opaque: bool
    frame_duration: bool
    pass1: bool
    pass2: bool
    loop_filter: bool
    gray: bool
    psnr: bool
    interlaced_dct: bool
    low_delay: bool
    global_header: bool
    bitexact: bool
    ac_pred: bool
    interlaced_me: bool
    closed_gop: bool

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
    def open(self, strict: bool = True) -> None: ...
    @staticmethod
    def create(
        codec: str | Codec, mode: Literal["r", "w"] | None = None
    ) -> CodecContext: ...
    def parse(
        self, raw_input: bytes | bytearray | memoryview | None = None
    ) -> list[Packet]: ...
    def flush_buffers(self) -> None: ...
