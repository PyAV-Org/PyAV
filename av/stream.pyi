from enum import Enum
from fractions import Fraction
from typing import ClassVar, Literal

from .codec import Codec, CodecContext
from .container import Container
from .frame import Frame
from .packet import Packet

class SideData(Enum):
    DISPLAYMATRIX: ClassVar[SideData]

class Stream:
    name: str | None
    container: Container
    codec: Codec
    codec_context: CodecContext
    metadata: dict[str, str]
    id: int
    profiles: list[str]
    profile: str | None
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
