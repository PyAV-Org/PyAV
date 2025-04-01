from typing import Literal

from .frame import VideoFrame
from .stream import VideoStream

_VideoCodecName = Literal[
    "gif",
    "h264",
    "hevc",
    "libvpx",
    "libx264",
    "mpeg4",
    "png",
    "qtrle",
]

__all__ = ("VideoFrame", "VideoStream")
