from av.descriptor import Descriptor
from av.option import Option

class Filter:
    name: str
    description: str
    descriptor: Descriptor
    options: tuple[Option, ...] | None
    flags: int
    command_support: bool

    def __init__(self, name: str) -> None: ...

filters_available: set[str]
