from .packet import Packet
from .stream import Stream

class BitStreamFilterContext:
    def __init__(
        self, filter_description: str | bytes, stream: Stream | None = None
    ): ...
    def filter(self, packet: Packet | None) -> list[Packet]: ...

bitstream_filters_available: set[str]
