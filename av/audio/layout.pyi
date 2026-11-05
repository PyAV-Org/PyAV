from dataclasses import dataclass
from typing import Self, final

@final
class AudioLayout:
    @property
    def name(self) -> str: ...
    @property
    def nb_channels(self) -> int: ...
    @property
    def channels(self) -> tuple[AudioChannel, ...]: ...
    def __new__(cls, layout: str | AudioLayout) -> Self: ...

@dataclass
class AudioChannel:
    name: str
    description: str
