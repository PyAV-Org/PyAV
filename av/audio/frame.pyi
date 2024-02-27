from av.frame import Frame

from .plane import AudioPlane

format_dtypes: dict[str, str]

class AudioFrame(Frame):
    planes: tuple[AudioPlane, ...]
    samples: int
    sample_rate: int
    rate: int

    def __init__(
        self,
        format: str = "s16",
        layout: str = "stereo",
        samples: int = 0,
        align: int = 1,
    ): ...
    def to_ndarray(self): ...
    @staticmethod
    def from_ndarray(
        array, format: str = "s16", layout: str = "stereo"
    ) -> AudioFrame: ...
