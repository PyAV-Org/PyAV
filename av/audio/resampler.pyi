from typing import Self, final

from .format import AudioFormat
from .frame import AudioFrame
from .layout import AudioLayout

@final
class AudioResampler:
    rate: int
    frame_size: int
    threads: int
    format: AudioFormat
    layout: AudioLayout
    options: dict[str, str]
    is_passthrough: bool

    def __new__(
        cls,
        format: str | int | AudioFormat | None = None,
        layout: str | int | AudioLayout | None = None,
        rate: int | None = None,
        frame_size: int | None = None,
        options: dict[str, str] | None = None,
        threads: int | None = None,
    ) -> Self: ...
    def resample(self, frame: AudioFrame | None) -> list[AudioFrame]: ...
