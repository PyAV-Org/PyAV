from enum import IntEnum
from pathlib import Path
from typing import Any, ClassVar, Union

import numpy as np

from av.frame import Frame

from .format import VideoFormat
from .plane import VideoPlane

_SupportedNDarray = Union[
    np.ndarray[Any, np.dtype[np.uint8]],
    np.ndarray[Any, np.dtype[np.uint16]],
    np.ndarray[Any, np.dtype[np.float16]],
    np.ndarray[Any, np.dtype[np.float32]],
]

supported_np_pix_fmts: set[str]

class PictureType(IntEnum):
    NONE = 0
    I = 1
    P = 2
    B = 3
    S = 4
    SI = 5
    SP = 6
    BI = 7

class VideoFrame(Frame):
    format: VideoFormat
    pts: int
    planes: tuple[VideoPlane, ...]
    pict_type: int
    colorspace: int
    color_range: int

    @property
    def time(self) -> float: ...
    @property
    def width(self) -> int: ...
    @property
    def height(self) -> int: ...
    @property
    def interlaced_frame(self) -> bool: ...
    @property
    def rotation(self) -> int: ...
    def __init__(
        self, width: int = 0, height: int = 0, format: str = "yuv420p"
    ) -> None: ...
    def reformat(
        self,
        width: int | None = None,
        height: int | None = None,
        format: str | None = None,
        src_colorspace: str | int | None = None,
        dst_colorspace: str | int | None = None,
        interpolation: int | str | None = None,
        src_color_range: int | str | None = None,
        dst_color_range: int | str | None = None,
    ) -> VideoFrame: ...
    def to_rgb(self, **kwargs: Any) -> VideoFrame: ...
    def save(self, filepath: str | Path) -> None: ...
    def to_image(self, **kwargs): ...
    def to_ndarray(
        self, channel_last: bool = False, **kwargs: Any
    ) -> _SupportedNDarray: ...
    @staticmethod
    def from_image(img): ...
    @staticmethod
    def from_numpy_buffer(
        array: _SupportedNDarray, format: str = "rgb24", width: int = 0
    ) -> VideoFrame: ...
    @staticmethod
    def from_ndarray(
        array: _SupportedNDarray, format: str = "rgb24", channel_last: bool = False
    ) -> VideoFrame: ...
    @staticmethod
    def from_bytes(
        data: bytes,
        width: int,
        height: int,
        format: str = "rgba",
        flip_horizontal: bool = False,
        flip_vertical: bool = False,
    ) -> VideoFrame: ...
