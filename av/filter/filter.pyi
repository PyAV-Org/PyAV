from av.descriptor import Descriptor
from av.option import Option

class Filter:
    name: str
    description: str
    descriptor: Descriptor
    options: tuple[Option, ...] | None
    flags: int
    dynamic_inputs: bool
    dynamic_outputs: bool
    timeline_support: bool
    slice_threads: bool
    command_support: bool

    def __init__(self, name: str) -> None: ...

filters_available: set[str]
