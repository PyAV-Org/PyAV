channel_descriptions: dict[str, str]

class AudioLayout:
    name: str
    layout: int
    nb_channels: int
    channels: tuple[AudioChannel, ...]
    def __init__(self, layout: int | str | AudioLayout): ...

class AudioChannel:
    name: str
    description: str
