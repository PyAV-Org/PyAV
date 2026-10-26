from typing import Self, final

@final
class VideoFormat:
    name: str
    bits_per_pixel: int
    padded_bits_per_pixel: int
    is_big_endian: bool
    has_palette: bool
    is_bit_stream: bool
    is_planar: bool
    width: int
    height: int
    @property
    def components(self) -> tuple[VideoFormatComponent, ...]: ...
    @property
    def is_rgb(self) -> bool: ...
    @property
    def is_bayer(self) -> bool: ...
    def __new__(cls, name: str, width: int = 0, height: int = 0) -> Self: ...
    def chroma_width(self, luma_width: int = 0) -> int: ...
    def chroma_height(self, luma_height: int = 0) -> int: ...
    def __int__(self) -> int: ...

@final
class VideoFormatComponent:
    index: int
    plane: int
    bits: int
    is_alpha: bool
    is_luma: bool
    is_chroma: bool
    width: int
    height: int

    def __new__(cls, format: VideoFormat, index: int) -> Self: ...

names: set[str]
