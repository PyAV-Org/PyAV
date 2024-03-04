from .buffer import Buffer
from .frame import Frame

class Plane(Buffer):
    frame: Frame
    index: int

    def __init__(self, frame: Frame, index: int) -> None: ...
