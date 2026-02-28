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

class ColorTrc(IntEnum):
    BT709 = cast(int, ...)
    UNSPECIFIED = cast(int, ...)
    GAMMA22 = cast(int, ...)
    GAMMA28 = cast(int, ...)
    SMPTE170M = cast(int, ...)
    SMPTE240M = cast(int, ...)
    LINEAR = cast(int, ...)
    LOG = cast(int, ...)
    LOG_SQRT = cast(int, ...)
    IEC61966_2_4 = cast(int, ...)
    BT1361_ECG = cast(int, ...)
    IEC61966_2_1 = cast(int, ...)
    BT2020_10 = cast(int, ...)
    BT2020_12 = cast(int, ...)
    SMPTE2084 = cast(int, ...)
    SMPTE428 = cast(int, ...)
    ARIB_STD_B67 = cast(int, ...)

class ColorPrimaries(IntEnum):
    BT709 = cast(int, ...)
    UNSPECIFIED = cast(int, ...)
    BT470M = cast(int, ...)
    BT470BG = cast(int, ...)
    SMPTE170M = cast(int, ...)
    SMPTE240M = cast(int, ...)
    FILM = cast(int, ...)
    BT2020 = cast(int, ...)
    SMPTE428 = cast(int, ...)
    SMPTE431 = cast(int, ...)
    SMPTE432 = cast(int, ...)
    EBU3213 = cast(int, ...)

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
        dst_color_trc: int | ColorTrc | None = None,
        dst_color_primaries: int | ColorPrimaries | None = None,
    ) -> VideoFrame: ...
