from types import CapsuleType
from typing import Any, Union

import numpy as np

from av.plane import Plane

from .frame import VideoFrame

_SupportedNDarray = Union[
    np.ndarray[Any, np.dtype[np.uint8]],
    np.ndarray[Any, np.dtype[np.uint16]],
]

class VideoPlane(Plane):
    line_size: int
    width: int
    height: int
    buffer_size: int

    def __init__(self, frame: VideoFrame, index: int) -> None: ...
    def to_ndarray(
        self, out: _SupportedNDarray | None = None
    ) -> _SupportedNDarray: ...
    def __dlpack_device__(self) -> tuple[int, int]: ...
    def __dlpack__(self, *, stream: int | None = None) -> CapsuleType: ...
