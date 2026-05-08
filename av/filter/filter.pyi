class Filter:
    name: str
    description: str
    flags: int

    def __init__(self, name: str) -> None: ...

filters_available: set[str]
