from .buffer import Buffer
from .frame import Frame

class Plane(Buffer):
    def __init__(self, frame: Frame, index: int) -> None: ...
