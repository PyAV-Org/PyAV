from fractions import Fraction
from typing import TypedDict

from av.sidedata.motionvectors import MotionVectors

class SideData(TypedDict, total=False):
    MOTION_VECTORS: MotionVectors

class Frame:
    dts: int | None
    pts: int | None
    time_base: Fraction
    side_data: SideData
    opaque: object
    @property
    def time(self) -> float | None: ...
    @property
    def is_corrupt(self) -> bool: ...
    @property
    def key_frame(self) -> bool: ...
    def make_writable(self) -> None: ...
