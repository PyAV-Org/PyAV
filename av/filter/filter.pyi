from typing import Self, final

from .link import FilterPad

@final
class Filter:
    name: str
    description: str
    flags: int

    @property
    def inputs(self) -> tuple[FilterPad, ...]: ...
    @property
    def outputs(self) -> tuple[FilterPad, ...]: ...
    def __new__(cls, name: str) -> Self: ...

filters_available: set[str]
