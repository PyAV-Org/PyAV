from types import CapsuleType
from typing import final

from av.plane import Plane

from .frame import VideoFrame

@final
class VideoPlane(Plane):
    line_size: int
    width: int
    height: int
    buffer_size: int

    def __init__(self, frame: VideoFrame, index: int) -> None: ...
    def __dlpack_device__(self) -> tuple[int, int]: ...
    def __dlpack__(self, *, stream: int | None = None) -> CapsuleType: ...
