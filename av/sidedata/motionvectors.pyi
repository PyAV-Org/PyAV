from collections.abc import Iterator
from typing import Self, final

import numpy as np
import numpy.typing as npt

from av.frame import Frame

from .sidedata import SideData

@final
class MotionVectors(SideData):
    def __new__(cls, sentinel: object, frame: Frame, index: int, /) -> Self: ...
    def __getitem__(self, index: int, /) -> MotionVector: ...
    def __iter__(self) -> Iterator[MotionVector]: ...
    def __len__(self) -> int: ...
    def to_ndarray(self) -> npt.NDArray[np.void]: ...

@final
class MotionVector:
    source: int
    w: int
    h: int
    src_x: int
    src_y: int
    dst_x: int
    dst_y: int
    motion_x: int
    motion_y: int
    motion_scale: int
    def __new__(
        cls, sentinel: object, parent: MotionVectors, index: int, /
    ) -> Self: ...
