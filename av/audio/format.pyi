class AudioFormat:
    name: str
    bytes: int
    bits: int
    is_planar: bool
    is_packed: bool
    planar: AudioFormat
    packed: AudioFormat
    container_name: str

    def __init__(self, name: str | AudioFormat) -> None: ...
