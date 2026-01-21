from typing import Any, Sequence, overload

import numpy as np

from .sidedata import SideData

class MotionVectors(SideData, Sequence[MotionVector]):
    @overload
    def __getitem__(self, index: int) -> MotionVector: ...
    @overload
    def __getitem__(self, index: slice) -> list[MotionVector]: ...
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
