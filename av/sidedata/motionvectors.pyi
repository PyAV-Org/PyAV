from collections.abc import Iterator
from typing import Any

import numpy as np

from .sidedata import SideData

class MotionVectors(SideData):
    def __getitem__(self, index: int) -> MotionVector: ...
    def __iter__(self) -> Iterator[MotionVector]: ...
    def __len__(self) -> int: ...
    def to_ndarray(self) -> np.ndarray[Any, Any]: ...

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
