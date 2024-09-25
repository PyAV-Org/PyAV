from typing import Any, Union

import numpy as np

from av.frame import Frame

from .format import AudioFormat
from .layout import AudioLayout
from .plane import AudioPlane

format_dtypes: dict[str, str]
_SupportedNDarray = Union[
    np.ndarray[Any, np.dtype[np.float64]],  # f8
    np.ndarray[Any, np.dtype[np.float32]],  # f4
    np.ndarray[Any, np.dtype[np.int32]],  # i4
    np.ndarray[Any, np.dtype[np.int16]],  # i2
    np.ndarray[Any, np.dtype[np.uint8]],  # u1
]

class _Format:
    def __get__(self, i: object | None, owner: type | None = None) -> AudioFormat: ...
    def __set__(self, instance: object, value: AudioFormat | str) -> None: ...

class _Layout:
    def __get__(self, i: object | None, owner: type | None = None) -> AudioLayout: ...
    def __set__(self, instance: object, value: AudioLayout | str) -> None: ...

class AudioFrame(Frame):
    planes: tuple[AudioPlane, ...]
    samples: int
    sample_rate: int
    rate: int
    format: _Format
    layout: _Layout

    def __init__(
        self,
        format: str = "s16",
        layout: str = "stereo",
        samples: int = 0,
        align: int = 1,
    ) -> None: ...
    @staticmethod
    def from_ndarray(
        array: _SupportedNDarray, format: str = "s16", layout: str = "stereo"
    ) -> AudioFrame: ...
    def to_ndarray(self) -> _SupportedNDarray: ...
