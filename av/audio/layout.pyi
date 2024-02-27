channel_descriptions: dict[str, str]

class AudioLayout:
    layout: int
    nb_channels: int
    channels: tuple[AudioChannels]

class AudioChannels:
    name: str
    description: str
