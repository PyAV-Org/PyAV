from typing import Any

class AudioFormat:
    name: str
    bytes: int
    bits: int
    is_planar: bool
    is_packed: bool
    planar: Any
    packed: Any
    container_name: str
