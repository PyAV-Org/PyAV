from .packet import Packet
from .stream import Stream

class BitStreamFilterContext:
    def __init__(
        self,
        filter_description: str | bytes,
        in_stream: Stream | None = None,
        out_stream: Stream | None = None,
    ): ...
    def filter(self, packet: Packet | None) -> list[Packet]: ...
    def flush(self) -> None: ...

bitstream_filters_available: set[str]
