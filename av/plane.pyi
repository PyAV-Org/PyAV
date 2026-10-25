from typing_extensions import disjoint_base

from .buffer import Buffer
from .frame import Frame

@disjoint_base
class Plane(Buffer):
    def __init__(self, frame: Frame, index: int) -> None: ...
