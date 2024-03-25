from numbers import Real
from pathlib import Path
from types import TracebackType
from typing import Any, Callable, Literal, Type, overload

from av.enum import EnumFlag
from av.format import ContainerFormat

from .input import InputContainer
from .output import OutputContainer
from .streams import StreamContainer

class Flags(EnumFlag):
    GENPTS: int
    IGNIDX: int
    NONBLOCK: int
    IGNDTS: int
    NOFILLIN: int
    NOPARSE: int
    NOBUFFER: int
    CUSTOM_IO: int
    DISCARD_CORRUPT: int
    FLUSH_PACKETS: int
    BITEXACT: int
    SORT_DTS: int
    FAST_SEEK: int
    SHORTEST: int
    AUTO_BSF: int

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
    stream_options: list[str]
    streams: StreamContainer
    metadata: dict[str, str]
    open_timeout: Real | None
    read_timeout: Real | None

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
) -> InputContainer | OutputContainer: ...
