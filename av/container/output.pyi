from fractions import Fraction
from typing import Literal, Sequence, overload

from av.audio.layout import AudioLayout
from av.audio.stream import AudioStream
from av.packet import Packet
from av.stream import Stream
from av.video.stream import VideoStream

from .core import Container

class OutputContainer(Container):
    def __enter__(self) -> OutputContainer: ...
    @overload
    def add_stream(
        self,
        codec_name: Literal["pcm_s16le", "aac", "mp3", "mp2"],
        rate: Fraction | int | float | None = None,
        template: None = None,
        options: dict[str, str] | None = None,
        **kwargs,
    ) -> AudioStream: ...
    @overload
    def add_stream(
        self,
        codec_name: Literal["h264", "mpeg4", "png", "qtrle"],
        rate: Fraction | int | float | None = None,
        template: None = None,
        options: dict[str, str] | None = None,
        **kwargs,
    ) -> VideoStream: ...
    @overload
    def add_stream(
        self,
        codec_name: str | None = None,
        rate: Fraction | int | float | None = None,
        template: Stream | None = None,
        options: dict[str, str] | None = None,
        **kwargs,
    ) -> Stream: ...
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
