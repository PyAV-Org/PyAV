import numpy as np
from PIL import Image

from av.enum import EnumItem
from av.frame import Frame

from .format import VideoFormat
from .plane import VideoPlane

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

    @staticmethod
    def from_image(img: Image.Image) -> VideoFrame: ...
    @staticmethod
    def from_ndarray(array: np.ndarray, format: str = "rgb24") -> VideoFrame: ...
    @staticmethod
    def from_numpy_buffer(array: np.ndarray, format: str = "rgb24"): ...
    def __init__(
        self, name: str, width: int = 0, height: int = 0, format: str = "yuv420p"
    ): ...
    def to_image(self, **kwargs) -> Image.Image: ...
    def to_ndarray(self, **kwargs) -> np.ndarray: ...
    def reformat(
        self,
        width: int | None = None,
        height: int | None = None,
        format: str | None = None,
        src_colorspace=None,
        dst_colorspace=None,
        interpolation: int | str | None = None,
        src_color_range: int | str | None = None,
        dst_color_range: int | str | None = None,
    ) -> VideoFrame: ...
