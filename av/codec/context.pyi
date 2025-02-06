from enum import Flag, IntEnum
from fractions import Fraction
from typing import ClassVar, Literal, cast

from av.packet import Packet

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
    drop_changed = cast(int, ...)
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
    @property
    def is_hwaccel(self) -> bool: ...
    def open(self, strict: bool = True) -> None: ...
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
