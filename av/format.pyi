__all__ = ("ContainerFormat", "formats_available")

from typing import Literal

from .enum import EnumFlag

class Flags(EnumFlag):
    NOFILE: int
    NEEDNUMBER: int
    SHOW_IDS: int
    GLOBALHEADER: int
    NOTIMESTAMPS: int
    GENERIC_INDEX: int
    TS_DISCONT: int
    VARIABLE_FPS: int
    NODIMENSIONS: int
    NOSTREAMS: int
    NOBINSEARCH: int
    NOGENSEARCH: int
    NO_BYTE_SEEK: int
    ALLOW_FLUSH: int
    TS_NONSTRICT: int
    TS_NEGATIVE: int
    SEEK_TO_PTS: int

class ContainerFormat:
    def __init__(self, name: str, mode: Literal["r", "w"] | None = None) -> None: ...
    name: str
    long_name: str
    is_input: bool
    is_output: bool
    extensions: set[str]

    # flags
    no_file: int
    need_number: int
    show_ids: int
    global_header: int
    no_timestamps: int
    generic_index: int
    ts_discont: int
    variable_fps: int
    no_dimensions: int
    no_streams: int
    no_bin_search: int
    no_gen_search: int
    no_byte_seek: int
    allow_flush: int
    ts_nonstrict: int
    ts_negative: int
    seek_to_pts: int

formats_available: set[str]
