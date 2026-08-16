from fractions import Fraction
from typing import TypedDict

from av.rational import AVRational
from av.sidedata.motionvectors import MotionVectors

class SideData(TypedDict, total=False):
    MOTION_VECTORS: MotionVectors

class Frame:
    dts: int | None
    pts: int | None
    duration: int
    @property
    def time_base(self) -> AVRational: ...
    @time_base.setter
    def time_base(self, value: AVRational | Fraction | int) -> None: ...
    side_data: SideData
    opaque: object
    @property
    def metadata(self) -> dict[str, str]: ...
    @property
    def time(self) -> float | None: ...
    @property
    def is_corrupt(self) -> bool: ...
    @property
    def key_frame(self) -> bool: ...
    def make_writable(self) -> None: ...
