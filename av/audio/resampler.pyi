from typing import Self, final

from .format import AudioFormat
from .frame import AudioFrame
from .layout import AudioLayout

@final
class AudioResampler:
    @property
    def rate(self) -> int: ...
    @property
    def frame_size(self) -> int: ...
    @property
    def threads(self) -> int: ...
    @property
    def format(self) -> AudioFormat: ...
    @property
    def layout(self) -> AudioLayout: ...
    @property
    def options(self) -> dict[str, str]: ...
    @property
    def is_passthrough(self) -> bool: ...
    def __new__(
        cls,
        format: str | AudioFormat | None = None,
        layout: str | AudioLayout | None = None,
        rate: int | None = None,
        frame_size: int | None = None,
        options: dict[str, str] | None = None,
        threads: int | None = None,
    ) -> Self: ...
    def resample(self, frame: AudioFrame | None) -> list[AudioFrame]: ...
