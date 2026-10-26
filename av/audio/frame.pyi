from typing import Any, Self, final

import numpy as np

from av.frame import Frame

from .format import AudioFormat
from .layout import AudioLayout
from .plane import AudioPlane

format_dtypes: dict[str, str]
_SupportedNDarray = (
    np.ndarray[Any, np.dtype[np.float64]]  # f8
    | np.ndarray[Any, np.dtype[np.float32]]  # f4
    | np.ndarray[Any, np.dtype[np.int32]]  # i4
    | np.ndarray[Any, np.dtype[np.int16]]  # i2
    | np.ndarray[Any, np.dtype[np.uint8]]  # u1
)

@final
class AudioFrame(Frame):
    planes: tuple[AudioPlane, ...]
    samples: int
    sample_rate: int
    rate: int
    @property
    def format(self) -> AudioFormat: ...
    @property
    def layout(self) -> AudioLayout: ...
    def __new__(
        cls,
        format: AudioFormat | str = "s16",
        layout: AudioLayout | str = "stereo",
        samples: int = 0,
        align: int = 1,
    ) -> Self: ...
    @staticmethod
    def from_ndarray(
        array: _SupportedNDarray,
        format: AudioFormat | str = "s16",
        layout: AudioLayout | str = "stereo",
    ) -> AudioFrame: ...
    def to_ndarray(self) -> _SupportedNDarray: ...
