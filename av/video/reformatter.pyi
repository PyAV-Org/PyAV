from av.enum import EnumItem

from .frame import VideoFrame

class Interpolation(EnumItem):
    FAST_BILINEAER: int
    BILINEAR: int
    BICUBIC: int
    X: int
    POINT: int
    AREA: int
    BICUBLIN: int
    GAUSS: int
    SINC: int
    LANCZOS: int
    SPLINE: int

class Colorspace(EnumItem):
    ITU709: int
    FCC: int
    ITU601: int
    ITU624: int
    SMPTE170M: int
    SMPTE240M: int
    DEFAULT: int
    itu709: int
    fcc: int
    itu601: int
    itu624: int
    smpte240: int
    default: int

class ColorRange(EnumItem):
    UNSPECIFIED: int
    MPEG: int
    JPEG: int
    NB: int

class VideoReformatter:
    def reformat(
        self,
        frame: VideoFrame,
        width: int | None = None,
        height: int | None = None,
        format: str | None = None,
        src_colorspace: int | None = None,
        dst_colorspace: int | None = None,
        interpolation: int | str | None = None,
        src_color_range: int | str | None = None,
        dst_color_range: int | str | None = None,
    ) -> VideoFrame: ...
