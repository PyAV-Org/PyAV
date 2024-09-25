from av.descriptor import Descriptor
from av.option import Option

from .pad import FilterPad

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
    inputs: tuple[FilterPad, ...]
    outputs: tuple[FilterPad, ...]

    def __init__(self, name: str) -> None: ...

filters_available: set[str]
