from fractions import Fraction

from av.audio.frame import AudioFrame
from av.audio.stream import AudioStream
from av.video.frame import VideoFrame
from av.video.stream import VideoStream

from .context import FilterContext
from .filter import Filter

class Graph:
    def __init__(self) -> None: ...
    def configure(self, auto_buffer: bool = True, force: bool = False) -> None: ...
    def add(self, filter: str | Filter, args=None, **kwargs: str) -> FilterContext: ...
    def add_buffer(
        self,
        template: VideoStream | None = None,
        width: int | None = None,
        height: int | None = None,
        format=None,
        name: str | None = None,
        time_base: Fraction | None = None,
    ) -> FilterContext: ...
    def add_abuffer(
        self,
        template: AudioStream | None = None,
        sample_rate: int | None = None,
        format=None,
        layout=None,
        channels: int | None = None,
        name: str | None = None,
        time_base: Fraction | None = None,
    ) -> FilterContext: ...
    def push(self, frame: None | AudioFrame | VideoFrame) -> None: ...
    def pull(self) -> VideoFrame | AudioFrame: ...
