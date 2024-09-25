class VideoFormat:
    name: str
    bits_per_pixel: int
    padded_bits_per_pixel: int
    is_big_endian: bool
    has_palette: bool
    is_bit_stream: bool
    is_planar: bool
    is_rgb: bool
    width: int
    height: int
    components: tuple[VideoFormatComponent, ...]

    def __init__(self, name: str, width: int = 0, height: int = 0) -> None: ...
    def chroma_width(self, luma_width: int = 0) -> int: ...
    def chroma_height(self, luma_height: int = 0) -> int: ...

class VideoFormatComponent:
    plane: int
    bits: int
    is_alpha: bool
    is_luma: bool
    is_chroma: bool
    width: int
    height: int

    def __init__(self, format: VideoFormat, index: int) -> None: ...
