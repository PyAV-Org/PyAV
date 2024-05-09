from collections.abc import Buffer
from fractions import Fraction

from av.subtitles.subtitle import SubtitleSet

from .stream import Stream

class Packet(Buffer):
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
    is_discard: bool
    is_trusted: bool
    is_disposable: bool

    def __init__(self, input: int | bytes | None = None) -> None: ...
    def decode(self) -> list[SubtitleSet]: ...
    def __buffer__(self, arg1) -> memoryview: ...
