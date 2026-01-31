from fractions import Fraction
from typing import Any

from av.audio.format import AudioFormat
from av.audio.frame import AudioFrame
from av.audio.layout import AudioLayout
from av.audio.stream import AudioStream
from av.video.format import VideoFormat
from av.video.frame import VideoFrame
from av.video.stream import VideoStream

from .context import FilterContext
from .filter import Filter

class Graph:
    configured: bool

    def __init__(self) -> None: ...
    def configure(self, auto_buffer: bool = True, force: bool = False) -> None: ...
    def link_nodes(self, *nodes: str) -> Graph: ...
    def add(self, node_name: str, filter: str | Filter, args: Any = None, **kwargs: str) -> None: ...
    def add_buffer(
        self,
        node_name: str,
        template: VideoStream | None = None,
        width: int | None = None,
        height: int | None = None,
        format: VideoFormat | None = None,
        name: str | None = None,
        time_base: Fraction | None = None,
    ) -> None: ...
    def add_abuffer(
        self,
        node_name: str,
        template: AudioStream | None = None,
        sample_rate: int | None = None,
        format: AudioFormat | str | None = None,
        layout: AudioLayout | str | None = None,
        channels: int | None = None,
        name: str | None = None,
        time_base: Fraction | None = None,
    ) -> None: ...
    def set_audio_frame_size(self, frame_size: int) -> None: ...
    def filter_vpush(self, frame: VideoFrame | None) -> None: ...
    def filter_vpull(self) -> VideoFrame: ...
    def filter_link_to(
            self, output_name: str, input_name: str, output_idx: int = 0, input_idx: int = 0
    ) -> None: ...
    def filter_push(self, name: str, frame: Frame | None) -> None: ...
    def filter_pull(self, name: str) -> Frame: ...
    def filter_process_command(
            self, name: str, cmd: str, arg: str | None = None, res_len: int = 1024, flags: int = 0
    ) -> str | None: ...
    def _ctx_from_name_or_die(self, name: str) -> FilterContext: ...