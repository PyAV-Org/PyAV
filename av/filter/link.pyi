from av.filter.context import FilterContext
from av.filter.filter import Filter
from av.filter.graph import Graph

class FilterPad:
    filter: Filter
    context: FilterContext
    is_input: bool
    index: int
    @property
    def is_output(self) -> bool: ...
    @property
    def name(self) -> str: ...
    @property
    def type(self) -> str: ...

class FilterContextPad(FilterPad):
    @property
    def link(self) -> FilterLink | None: ...
    @property
    def linked(self) -> FilterContextPad | None: ...

class FilterLink:
    @property
    def graph(self) -> Graph: ...
    @property
    def input(self) -> FilterContextPad: ...
    @property
    def output(self) -> FilterContextPad: ...
