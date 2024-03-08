from fractions import Fraction
from typing import Iterator

from av.subtitles.subtitle import SubtitleSet

from .stream import Stream

class Packet:
    stream: Stream
    stream_index: int
    time_base: Fraction
    pts: int | None
    dts: int
    pos: int | None
    size: int
    duration: int | None
    is_keyframe: bool
    is_corrupt: bool

    def __init__(self, input: int | None = None) -> None: ...
    def decode(self) -> Iterator[SubtitleSet]: ...
