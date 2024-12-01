from enum import Flag, IntEnum
from fractions import Fraction
from typing import ClassVar, Literal

from av.packet import Packet

from .codec import Codec

class ThreadType(Flag):
    NONE: ClassVar[ThreadType]
    FRAME: ClassVar[ThreadType]
    SLICE: ClassVar[ThreadType]
    AUTO: ClassVar[ThreadType]
    def __get__(self, i: object | None, owner: type | None = None) -> ThreadType: ...
    def __set__(self, instance: object, value: int | str | ThreadType) -> None: ...

class Flags(IntEnum):
    unaligned: int
    qscale: int
    four_mv: int
    output_corrupt: int
    qpel: int
    drop_changed: int
    recon_frame: int
    copy_opaque: int
    frame_duration: int
    pass1: int
    pass2: int
    loop_filter: int
    gray: int
    psnr: int
    interlaced_dct: int
    low_delay: int
    global_header: int
    bitexact: int
    ac_pred: int
    interlaced_me: int
    closed_gop: int

class Flags2(IntEnum):
    fast: int
    no_output: int
    local_header: int
    chunks: int
    ignore_crop: int
    show_all: int
    export_mvs: int
    skip_manual: int
    ro_flush_noop: int

class CodecContext:
    name: str
    type: Literal["video", "audio", "data", "subtitle", "attachment"]
    options: dict[str, str]
    profile: str | None
    @property
    def profiles(self) -> list[str]: ...
    extradata: bytes | None
    time_base: Fraction
    codec_tag: str
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
    def open(self, strict: bool = True) -> None: ...
    @staticmethod
    def create(
        codec: str | Codec, mode: Literal["r", "w"] | None = None
    ) -> CodecContext: ...
    def parse(
        self, raw_input: bytes | bytearray | memoryview | None = None
    ) -> list[Packet]: ...
    def flush_buffers(self) -> None: ...
