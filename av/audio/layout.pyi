from dataclasses import dataclass

class AudioLayout:
    name: str
    nb_channels: int
    channels: tuple[AudioChannel, ...]
    def __init__(self, layout: str | AudioLayout): ...

@dataclass
class AudioChannel:
    name: str
    description: str
