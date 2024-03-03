channel_descriptions: dict[str, str]

class AudioLayout:
    name: str
    layout: int
    nb_channels: int
    channels: tuple[AudioChannel, ...]

class AudioChannel:
    name: str
    description: str
