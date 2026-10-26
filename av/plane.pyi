from typing import Self

from typing_extensions import disjoint_base

from .buffer import Buffer
from .frame import Frame

@disjoint_base
class Plane(Buffer):
    def __new__(cls, frame: Frame, index: int) -> Self: ...
