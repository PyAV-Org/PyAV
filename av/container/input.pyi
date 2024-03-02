from typing import Iterator, Literal, overload

from av.audio.frame import AudioFrame
from av.audio.stream import AudioStream
from av.packet import Packet
from av.subtitles.stream import SubtitleStream
from av.subtitles.subtitle import SubtitleSet
from av.video.frame import VideoFrame
from av.video.stream import VideoStream

from .core import Container
from .streams import Stream

class InputContainer(Container):
    bit_rate: int
    size: int

    def __enter__(self) -> InputContainer: ...
    def close(self) -> None: ...
    def demux(self, *args, **kwargs) -> Iterator[Packet]: ...
    @overload
    def decode(self, *args: VideoStream) -> Iterator[VideoFrame]: ...
    @overload
    def decode(self, *args: AudioStream) -> Iterator[AudioFrame]: ...
    @overload
    def decode(self, *args: SubtitleStream) -> Iterator[SubtitleSet]: ...
    @overload
    def decode(
        self, *args, **kwargs
    ) -> Iterator[VideoFrame | AudioFrame | SubtitleSet]: ...
    def seek(
        self,
        offset: int,
        *,
        whence: Literal["time"] = "time",
        backward: bool = True,
        any_frame: bool = False,
        stream: Stream | VideoStream | AudioStream | None = None,
        unsupported_frame_offset: bool = False,
        unsupported_byte_offset: bool = False,
    ) -> None: ...
