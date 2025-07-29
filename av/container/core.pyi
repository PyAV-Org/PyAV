from enum import Flag, IntEnum
from fractions import Fraction
from pathlib import Path
from types import TracebackType
from typing import Any, Callable, ClassVar, Literal, Type, cast, overload

from av.codec.hwaccel import HWAccel
from av.format import ContainerFormat

from .input import InputContainer
from .output import OutputContainer
from .streams import StreamContainer

Real = int | float | Fraction

class Flags(Flag):
    gen_pts = cast(ClassVar[Flags], ...)
    ign_idx = cast(ClassVar[Flags], ...)
    non_block = cast(ClassVar[Flags], ...)
    ign_dts = cast(ClassVar[Flags], ...)
    no_fillin = cast(ClassVar[Flags], ...)
    no_parse = cast(ClassVar[Flags], ...)
    no_buffer = cast(ClassVar[Flags], ...)
    custom_io = cast(ClassVar[Flags], ...)
    discard_corrupt = cast(ClassVar[Flags], ...)
    flush_packets = cast(ClassVar[Flags], ...)
    bitexact = cast(ClassVar[Flags], ...)
    sort_dts = cast(ClassVar[Flags], ...)
    fast_seek = cast(ClassVar[Flags], ...)
    shortest = cast(ClassVar[Flags], ...)
    auto_bsf = cast(ClassVar[Flags], ...)

class AudioCodec(IntEnum):
    none = cast(int, ...)
    pcm_alaw = cast(int, ...)
    pcm_bluray = cast(int, ...)
    pcm_dvd = cast(int, ...)
    pcm_f16le = cast(int, ...)
    pcm_f24le = cast(int, ...)
    pcm_f32be = cast(int, ...)
    pcm_f32le = cast(int, ...)
    pcm_f64be = cast(int, ...)
    pcm_f64le = cast(int, ...)
    pcm_lxf = cast(int, ...)
    pcm_mulaw = cast(int, ...)
    pcm_s16be = cast(int, ...)
    pcm_s16be_planar = cast(int, ...)
    pcm_s16le = cast(int, ...)
    pcm_s16le_planar = cast(int, ...)
    pcm_s24be = cast(int, ...)
    pcm_s24daud = cast(int, ...)
    pcm_s24le = cast(int, ...)
    pcm_s24le_planar = cast(int, ...)
    pcm_s32be = cast(int, ...)
    pcm_s32le = cast(int, ...)
    pcm_s32le_planar = cast(int, ...)
    pcm_s64be = cast(int, ...)
    pcm_s64le = cast(int, ...)
    pcm_s8 = cast(int, ...)
    pcm_s8_planar = cast(int, ...)
    pcm_u16be = cast(int, ...)
    pcm_u16le = cast(int, ...)
    pcm_u24be = cast(int, ...)
    pcm_u24le = cast(int, ...)
    pcm_u32be = cast(int, ...)
    pcm_u32le = cast(int, ...)
    pcm_u8 = cast(int, ...)
    pcm_vidc = cast(int, ...)

class Container:
    writeable: bool
    name: str
    metadata_encoding: str
    metadata_errors: str
    file: Any
    buffer_size: int
    input_was_opened: bool
    io_open: Any
    open_files: Any
    format: ContainerFormat
    options: dict[str, str]
    container_options: dict[str, str]
    stream_options: list[dict[str, str]]
    streams: StreamContainer
    metadata: dict[str, str]
    open_timeout: Real | None
    read_timeout: Real | None
    flags: int

    def __enter__(self) -> Container: ...
    def __exit__(
        self,
        exc_type: Type[BaseException] | None,
        exc_val: BaseException | None,
        exc_tb: TracebackType | None,
    ) -> bool: ...
    def set_timeout(self, timeout: Real | None) -> None: ...
    def start_timeout(self) -> None: ...

@overload
def open(
    file: Any,
    mode: Literal["r"],
    format: str | None = None,
    options: dict[str, str] | None = None,
    container_options: dict[str, str] | None = None,
    stream_options: list[str] | None = None,
    metadata_encoding: str = "utf-8",
    metadata_errors: str = "strict",
    buffer_size: int = 32768,
    timeout: Real | None | tuple[Real | None, Real | None] = None,
    io_open: Callable[..., Any] | None = None,
    hwaccel: HWAccel | None = None,
) -> InputContainer: ...
@overload
def open(
    file: str | Path,
    mode: Literal["r"] | None = None,
    format: str | None = None,
    options: dict[str, str] | None = None,
    container_options: dict[str, str] | None = None,
    stream_options: list[str] | None = None,
    metadata_encoding: str = "utf-8",
    metadata_errors: str = "strict",
    buffer_size: int = 32768,
    timeout: Real | None | tuple[Real | None, Real | None] = None,
    io_open: Callable[..., Any] | None = None,
    hwaccel: HWAccel | None = None,
) -> InputContainer: ...
@overload
def open(
    file: Any,
    mode: Literal["w"],
    format: str | None = None,
    options: dict[str, str] | None = None,
    container_options: dict[str, str] | None = None,
    stream_options: list[str] | None = None,
    metadata_encoding: str = "utf-8",
    metadata_errors: str = "strict",
    buffer_size: int = 32768,
    timeout: Real | None | tuple[Real | None, Real | None] = None,
    io_open: Callable[..., Any] | None = None,
    hwaccel: HWAccel | None = None,
) -> OutputContainer: ...
@overload
def open(
    file: Any,
    mode: Literal["r", "w"] | None = None,
    format: str | None = None,
    options: dict[str, str] | None = None,
    container_options: dict[str, str] | None = None,
    stream_options: list[str] | None = None,
    metadata_encoding: str = "utf-8",
    metadata_errors: str = "strict",
    buffer_size: int = 32768,
    timeout: Real | None | tuple[Real | None, Real | None] = None,
    io_open: Callable[..., Any] | None = None,
    hwaccel: HWAccel | None = None,
) -> InputContainer | OutputContainer: ...
