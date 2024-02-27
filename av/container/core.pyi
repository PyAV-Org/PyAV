from numbers import Real
from pathlib import Path
from typing import Any, Iterator, Literal, overload

from .input import InputContainer
from .output import OutputContainer
from .streams import StreamContainer

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
    format: str | None
    options: dict[str, str]
    container_options: dict[str, str]
    stream_options: list[str]
    streams: StreamContainer
    duration: int | None
    metadata: dict[str, str]
    open_timeout: Real | None
    read_timeout: Real | None

    def __enter__(self) -> Container: ...
    def __exit__(self, exc_type, exc_val, exc_tb): ...
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
    timeout=Real | None | tuple[Real | None, Real | None],
    io_open=None,
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
    timeout=Real | None | tuple[Real | None, Real | None],
    io_open=None,
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
    timeout=Real | None | tuple[Real | None, Real | None],
    io_open=None,
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
    timeout=Real | None | tuple[Real | None, Real | None],
    io_open=None,
) -> InputContainer | OutputContainer: ...
