from av.filter.graph import Graph

from .format import AudioFormat
from .frame import AudioFrame
from .layout import AudioLayout

class AudioResampler:
    rate: int
    frame_size: int
    format: AudioFormat
    layout: AudioLayout
    options: dict[str, str]
    graph: Graph | None

    def __init__(
        self,
        format: str | int | AudioFormat | None = None,
        layout: str | int | AudioLayout | None = None,
        rate: int | None = None,
        frame_size: int | None = None,
        options: dict[str, str] | None = None,
    ) -> None: ...
    def resample(self, frame: AudioFrame | None) -> list[AudioFrame]: ...
