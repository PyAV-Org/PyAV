from enum import IntEnum
from typing import cast

from .frame import VideoFrame

class Interpolation(IntEnum):
    FAST_BILINEAER = cast(int, ...)
    BILINEAR = cast(int, ...)
    BICUBIC = cast(int, ...)
    X = cast(int, ...)
    POINT = cast(int, ...)
    AREA = cast(int, ...)
    BICUBLIN = cast(int, ...)
    GAUSS = cast(int, ...)
    SINC = cast(int, ...)
    LANCZOS = cast(int, ...)
    SPLINE = cast(int, ...)

class Colorspace(IntEnum):
    ITU709 = cast(int, ...)
    FCC = cast(int, ...)
    ITU601 = cast(int, ...)
    ITU624 = cast(int, ...)
    SMPTE170M = cast(int, ...)
    SMPTE240M = cast(int, ...)
    DEFAULT = cast(int, ...)
    itu709 = cast(int, ...)
    fcc = cast(int, ...)
    itu601 = cast(int, ...)
    itu624 = cast(int, ...)
    smpte170m = cast(int, ...)
    smpte240m = cast(int, ...)
    default = cast(int, ...)

class ColorRange(IntEnum):
    UNSPECIFIED = 0
    MPEG = 1
    JPEG = 2
    NB = 3

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
