from typing import Iterator, overload

from av.audio.stream import AudioStream
from av.data.stream import DataStream
from av.stream import Stream
from av.subtitles.stream import SubtitleStream
from av.video.stream import VideoStream

class StreamContainer:
    video: tuple[VideoStream, ...]
    audio: tuple[AudioStream, ...]
    subtitles: tuple[SubtitleStream, ...]
    data: tuple[DataStream, ...]
    other: tuple[Stream, ...]

    def __init__(self) -> None: ...
    def add_stream(self, stream: Stream) -> None: ...
    def __len__(self) -> int: ...
    def __iter__(self) -> Iterator[Stream]: ...
    @overload
    def __getitem__(self, index: int) -> Stream: ...
    @overload
    def __getitem__(self, index: slice) -> list[Stream]: ...
    @overload
    def __getitem__(self, index: int | slice) -> Stream | list[Stream]: ...
    def get(
        self,
        *args: int | Stream | dict[str, int | tuple[int, ...]],
        **kwargs: int | tuple[int, ...],
    ) -> list[Stream]: ...
