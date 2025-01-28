from enum import Flag
from fractions import Fraction
from pathlib import Path
from types import TracebackType
from typing import Any, Callable, ClassVar, Literal, Type, overload

from av.codec.hwaccel import HWAccel
from av.format import ContainerFormat

from .input import InputContainer
from .output import OutputContainer
from .streams import StreamContainer

Real = int | float | Fraction

class Flags(Flag):
    gen_pts: ClassVar[Flags]
    ign_idx: ClassVar[Flags]
    non_block: ClassVar[Flags]
    ign_dts: ClassVar[Flags]
    no_fillin: ClassVar[Flags]
    no_parse: ClassVar[Flags]
    no_buffer: ClassVar[Flags]
    custom_io: ClassVar[Flags]
    discard_corrupt: ClassVar[Flags]
    flush_packets: ClassVar[Flags]
    bitexact: ClassVar[Flags]
    sort_dts: ClassVar[Flags]
    fast_seek: ClassVar[Flags]
    shortest: ClassVar[Flags]
    auto_bsf: ClassVar[Flags]

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
    def err_check(self, value: int) -> int: ...
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
