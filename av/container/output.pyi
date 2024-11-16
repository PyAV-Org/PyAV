from fractions import Fraction
from typing import Literal, Sequence, TypeVar, Union, overload

from av.audio.stream import AudioStream
from av.data.stream import DataStream
from av.packet import Packet
from av.stream import Stream
from av.subtitles.stream import SubtitleStream
from av.video.stream import VideoStream

from .core import Container

_StreamT = TypeVar("_StreamT", bound=Union[VideoStream, AudioStream, SubtitleStream])

class OutputContainer(Container):
    def __enter__(self) -> OutputContainer: ...
    @overload
    def add_stream(
        self,
        codec_name: Literal["pcm_s16le", "aac", "mp3", "mp2"],
        rate: int | None = None,
        options: dict[str, str] | None = None,
        **kwargs,
    ) -> AudioStream: ...
    @overload
    def add_stream(
        self,
        codec_name: Literal["h264", "hevc", "mpeg4", "png", "gif", "qtrle"],
        rate: Fraction | int | None = None,
        options: dict[str, str] | None = None,
        **kwargs,
    ) -> VideoStream: ...
    @overload
    def add_stream(
        self,
        codec_name: str,
        rate: Fraction | int | None = None,
        options: dict[str, str] | None = None,
        **kwargs,
    ) -> VideoStream | AudioStream | SubtitleStream: ...
    def add_stream_from_template(self, template: _StreamT, **kwargs) -> _StreamT: ...
    def add_data_stream(
        self, codec_name: str | None = None, options: dict[str, str] | None = None
    ) -> DataStream: ...
    def start_encoding(self) -> None: ...
    def close(self) -> None: ...
    def mux(self, packets: Packet | Sequence[Packet]) -> None: ...
    def mux_one(self, packet: Packet) -> None: ...
    @property
    def default_video_codec(self) -> str: ...
    @property
    def default_audio_codec(self) -> str: ...
    @property
    def default_subtitle_codec(self) -> str: ...
    @property
    def supported_codecs(self) -> set[str]: ...
