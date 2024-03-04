from typing import NoReturn

from .option import Option

class Descriptor:
    name: str
    options: tuple[Option, ...]

    def __init__(self) -> NoReturn: ...
