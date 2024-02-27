from fractions import Fraction
from typing import Literal

from .enum import EnumItem

class SideData(EnumItem):
    DISPLAYMATRIX: int

class Stream:
    name: str | None
    id: int
    profile: str
    side_data: dict[str, str]
    index: int
    time_base: Fraction | None
    average_rate: Fraction | None
    base_rate: Fraction | None
    guessed_rate: Fraction | None
    start_time: int | None
    duration: int | None
    frames: int
    language: str | None
    type: Literal["video", "audio", "data", "subtitle", "attachment"]

    def encode(self, frame=None): ...
    def decode(self, packet=None): ...
