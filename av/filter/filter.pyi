class Filter:
    name: str
    description: str
    options: tuple | None
    dynamic_inputs: bool
    dynamic_outputs: bool
    timeline_support: bool
    slice_threads: bool
    command_support: bool
    inputs: tuple
    outputs: tuple

filters_available: set[str]
