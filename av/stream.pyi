from fractions import Fraction
from typing import Literal

from .codec import CodecContext
from .container import Container
from .enum import EnumItem
from .frame import Frame
from .packet import Packet

class SideData(EnumItem):
    DISPLAYMATRIX: int

class Stream:
    name: str | None
    thread_type: Literal["NONE", "FRAME", "SLICE", "AUTO"]

    container: Container
    codec_context: CodecContext
    metadata: dict[str, str]
    id: int
    profile: str
    nb_side_data: int
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
