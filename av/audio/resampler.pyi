from .format import AudioFormat
from .frame import AudioFrame

class AudioResampler:
    rate: int
    frame_size: int
    format: AudioFormat
    graph: None

    def __init__(
        self,
        format=None,
        layout=None,
        rate: int | None = None,
        frame_size: int | None = None,
    ): ...
    def resample(self, frame: AudioFrame | None) -> list: ...
