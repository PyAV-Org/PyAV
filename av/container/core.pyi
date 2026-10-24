from collections.abc import Callable
from enum import Flag, IntEnum
from fractions import Fraction
from pathlib import Path
from types import TracebackType
from typing import (
    Any,
    ClassVar,
    Literal,
    Self,
    TypedDict,
    cast,
    overload,
    type_check_only,
)

from typing_extensions import disjoint_base

from av.codec.hwaccel import HWAccel
from av.format import ContainerFormat
from av.rational import AVRational

from .input import InputContainer
from .output import OutputContainer
from .streams import StreamContainer

type _Real = int | float | Fraction | AVRational

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
    none = ...
    pcm_alaw = ...
    pcm_bluray = ...
    pcm_dvd = ...
    pcm_f16le = ...
    pcm_f24le = ...
    pcm_f32be = ...
    pcm_f32le = ...
    pcm_f64be = ...
    pcm_f64le = ...
    pcm_lxf = ...
    pcm_mulaw = ...
    pcm_s16be = ...
    pcm_s16be_planar = ...
    pcm_s16le = ...
    pcm_s16le_planar = ...
    pcm_s24be = ...
    pcm_s24daud = ...
    pcm_s24le = ...
    pcm_s24le_planar = ...
    pcm_s32be = ...
    pcm_s32le = ...
    pcm_s32le_planar = ...
    pcm_s64be = ...
    pcm_s64le = ...
    pcm_s8 = ...
    pcm_s8_planar = ...
    pcm_u16be = ...
    pcm_u16le = ...
    pcm_u24be = ...
    pcm_u24le = ...
    pcm_u32be = ...
    pcm_u32le = ...
    pcm_u8 = ...
    pcm_vidc = ...

@type_check_only
class Chapter(TypedDict):
    id: int
    start: int
    end: int
    time_base: AVRational
    metadata: dict[str, str]

@disjoint_base
class Container:
    name: str
    file: Any
    io_open: Any
    open_files: Any
    format: ContainerFormat
    options: dict[str, str]
    container_options: dict[str, str]
    streams: StreamContainer
    metadata: dict[str, str]
    open_timeout: _Real | None
    read_timeout: _Real | None
    flags: int
    video_codec_id: int
    def dumps_format(self) -> str: ...
    def __enter__(self) -> Self: ...
    def __exit__(
        self,
        exc_type: type[BaseException] | None,
        exc_val: BaseException | None,
        exc_tb: TracebackType | None,
    ) -> None: ...
    @property
    def input_was_opened(self) -> bool: ...
    def close(self) -> None: ...
    def chapters(self) -> list[Chapter]: ...
    def set_chapters(self, chapters: list[Chapter]) -> None: ...

@overload
def open(
    file: Any,
    mode: Literal["r"],
    format: str | None = None,
    options: dict[str, str] | None = None,
    container_options: dict[str, str] | None = None,
    buffer_size: int = 32768,
    timeout: _Real | None | tuple[_Real | None, _Real | None] = None,
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
    buffer_size: int = 32768,
    timeout: _Real | None | tuple[_Real | None, _Real | None] = None,
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
    buffer_size: int = 32768,
    timeout: _Real | None | tuple[_Real | None, _Real | None] = None,
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
    buffer_size: int = 32768,
    timeout: _Real | None | tuple[_Real | None, _Real | None] = None,
    io_open: Callable[..., Any] | None = None,
    hwaccel: HWAccel | None = None,
) -> InputContainer | OutputContainer: ...
