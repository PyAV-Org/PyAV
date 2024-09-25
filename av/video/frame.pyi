from typing import Any, Union

import numpy as np
from PIL import Image

from av.enum import EnumItem
from av.frame import Frame

from .format import VideoFormat
from .plane import VideoPlane

_SupportedNDarray = Union[
    np.ndarray[Any, np.dtype[np.uint8]],
    np.ndarray[Any, np.dtype[np.uint16]],
    np.ndarray[Any, np.dtype[np.float32]],
]

class PictureType(EnumItem):
    NONE: int
    I: int
    P: int
    B: int
    S: int
    SI: int
    SP: int
    BI: int

class VideoFrame(Frame):
    format: VideoFormat
    pts: int
    time: float
    planes: tuple[VideoPlane, ...]
    width: int
    height: int
    key_frame: bool
    interlaced_frame: bool
    pict_type: int
    colorspace: int
    color_range: int

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
    def to_image(self, **kwargs: Any) -> Image.Image: ...
    def to_ndarray(self, **kwargs: Any) -> _SupportedNDarray: ...
    @staticmethod
    def from_image(img: Image.Image) -> VideoFrame: ...
    @staticmethod
    def from_numpy_buffer(
        array: _SupportedNDarray, format: str = "rgb24"
    ) -> VideoFrame: ...
    @staticmethod
    def from_ndarray(array: _SupportedNDarray, format: str = "rgb24") -> VideoFrame: ...
    @staticmethod
    def from_bytes(
        data: bytes,
        width: int,
        height: int,
        format: str = "rgba",
        flip_horizontal: bool = False,
        flip_vertical: bool = False,
    ) -> VideoFrame: ...
