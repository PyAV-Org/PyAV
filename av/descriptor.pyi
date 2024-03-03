from av.option import Option

class Descriptor:
    name: str
    options: tuple[Option, ...]

    def __init__(self, sentinel: object) -> None: ...
