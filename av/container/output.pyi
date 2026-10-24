from collections.abc import Sequence
from fractions import Fraction
from typing import Any, final, overload

from av.audio import _AudioCodecName
from av.audio.stream import AudioStream
from av.codec.hwaccel import HWAccel
from av.packet import Packet
from av.rational import AVRational
from av.stream import AttachmentStream, DataStream, Stream
from av.subtitles import _SubtitleCodecName
from av.subtitles.stream import SubtitleStream
from av.video import _VideoCodecName
from av.video.stream import VideoStream

from .core import Container

@final
class OutputContainer(Container):
    @overload
    def add_stream(
        self,
        codec_name: _AudioCodecName,
        rate: int | None = None,
        options: dict[str, str] | None = None,
        **kwargs: Any,
    ) -> AudioStream: ...
    @overload
    def add_stream(
        self,
        codec_name: _VideoCodecName,
        rate: AVRational | Fraction | int | None = None,
        options: dict[str, str] | None = None,
        hwaccel: HWAccel | None = None,
        **kwargs: Any,
    ) -> VideoStream: ...
    @overload
    def add_stream(
        self,
        codec_name: _SubtitleCodecName,
        rate: AVRational | Fraction | int | None = None,
        options: dict[str, str] | None = None,
        **kwargs: Any,
    ) -> SubtitleStream: ...
    @overload
    def add_stream(
        self,
        codec_name: str,
        rate: AVRational | Fraction | int | None = None,
        options: dict[str, str] | None = None,
        hwaccel: HWAccel | None = None,
        **kwargs: Any,
    ) -> VideoStream | AudioStream | SubtitleStream: ...
    def add_mux_stream(
        self,
        codec_name: str,
        rate: AVRational | Fraction | int | None = None,
        **kwargs: Any,
    ) -> Stream: ...
    def add_stream_from_template[StreamT: Stream](
        self, template: StreamT, opaque: bool | None = None, **kwargs: Any
    ) -> StreamT: ...
    def add_attachment(
        self, name: str, mimetype: str, data: bytes
    ) -> AttachmentStream: ...
    def add_data_stream(
        self, codec_name: str | None = None, options: dict[str, str] | None = None
    ) -> DataStream: ...
    def start_encoding(self) -> None: ...
    def mux(self, packets: Packet[Any] | Sequence[Packet[Any]]) -> None: ...
    def mux_one(self, packet: Packet[Any]) -> None: ...
    @property
    def default_video_codec(self) -> str: ...
    @property
    def default_audio_codec(self) -> str: ...
    @property
    def default_subtitle_codec(self) -> str: ...
    @property
    def supported_codecs(self) -> set[str]: ...
