__all__ = ("Flags", "ContainerFormat", "formats_available")

from enum import Flag
from typing import ClassVar, Literal

class Flags(Flag):
    no_file: ClassVar[Flags]
    need_number: ClassVar[Flags]
    show_ids: ClassVar[Flags]
    global_header: ClassVar[Flags]
    no_timestamps: ClassVar[Flags]
    generic_index: ClassVar[Flags]
    ts_discont: ClassVar[Flags]
    variable_fps: ClassVar[Flags]
    no_dimensions: ClassVar[Flags]
    no_streams: ClassVar[Flags]
    no_bin_search: ClassVar[Flags]
    no_gen_search: ClassVar[Flags]
    no_byte_seek: ClassVar[Flags]
    allow_flush: ClassVar[Flags]
    ts_nonstrict: ClassVar[Flags]
    ts_negative: ClassVar[Flags]
    seek_to_pts: ClassVar[Flags]

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
