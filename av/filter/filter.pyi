from .link import FilterPad

class Filter:
    name: str
    description: str
    flags: int

    @property
    def inputs(self) -> tuple[FilterPad, ...]: ...
    @property
    def outputs(self) -> tuple[FilterPad, ...]: ...

    def __init__(self, name: str) -> None: ...

filters_available: set[str]
