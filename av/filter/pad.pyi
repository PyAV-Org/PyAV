from .link import FilterLink

class FilterPad:
    is_output: bool
    name: str
    type: str

class FilterContextPad(FilterPad):
    link: FilterLink | None
    linked: FilterContextPad | None
