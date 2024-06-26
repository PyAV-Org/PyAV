from av.filter import Graph
from av.frame import Frame

from .pad import FilterContextPad

class FilterContext:
    name: str | None
    inputs: tuple[FilterContextPad, ...]
    outputs: tuple[FilterContextPad, ...]

    def init(self, args: str | None = None, **kwargs: str | None) -> None: ...
    def link_to(
        self, input_: FilterContext, output_idx: int = 0, input_idx: int = 0
    ) -> None: ...
    @property
    def graph(self) -> Graph: ...
    def push(self, frame: Frame) -> None: ...
    def pull(self) -> Frame: ...
