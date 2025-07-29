__all__ = ("Flags", "ContainerFormat", "formats_available")

from enum import Flag
from typing import ClassVar, Literal, cast

class Flags(Flag):
    no_file = cast(ClassVar[Flags], ...)
    need_number = cast(ClassVar[Flags], ...)
    show_ids = cast(ClassVar[Flags], ...)
    global_header = cast(ClassVar[Flags], ...)
    no_timestamps = cast(ClassVar[Flags], ...)
    generic_index = cast(ClassVar[Flags], ...)
    ts_discont = cast(ClassVar[Flags], ...)
    variable_fps = cast(ClassVar[Flags], ...)
    no_dimensions = cast(ClassVar[Flags], ...)
    no_streams = cast(ClassVar[Flags], ...)
    no_bin_search = cast(ClassVar[Flags], ...)
    no_gen_search = cast(ClassVar[Flags], ...)
    no_byte_seek = cast(ClassVar[Flags], ...)
    allow_flush = cast(ClassVar[Flags], ...)
    ts_nonstrict = cast(ClassVar[Flags], ...)
    ts_negative = cast(ClassVar[Flags], ...)
    seek_to_pts = cast(ClassVar[Flags], ...)

class ContainerFormat:
    def __init__(self, name: str, mode: Literal["r", "w"] | None = None) -> None: ...
    @property
    def name(self) -> str: ...
    @property
    def long_name(self) -> str: ...
    @property
    def is_input(self) -> bool: ...
    @property
    def is_output(self) -> bool: ...
    @property
    def extensions(self) -> set[str]: ...
    @property
    def flags(self) -> int: ...
    @property
    def no_file(self) -> bool: ...

formats_available: set[str]
