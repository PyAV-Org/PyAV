from dataclasses import dataclass
from typing import Self, final

@final
class AudioLayout:
    name: str
    nb_channels: int
    channels: tuple[AudioChannel, ...]
    def __new__(cls, layout: str | AudioLayout) -> Self: ...

@dataclass
class AudioChannel:
    name: str
    description: str
