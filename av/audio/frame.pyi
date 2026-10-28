from typing import Self, final

import numpy as np
import numpy.typing as npt

from av.frame import Frame

from .format import AudioFormat
from .layout import AudioLayout
from .plane import AudioPlane

format_dtypes: dict[str, str]
_SupportedNDarray = (
    npt.NDArray[np.float64]
    | npt.NDArray[np.float32]
    | npt.NDArray[np.int32]
    | npt.NDArray[np.int16]
    | npt.NDArray[np.uint8]
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
