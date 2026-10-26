from typing import Any, Self, final

from .codec import Codec
from .packet import Packet
from .stream import Stream

@final
class BitStreamFilterContext:
    def __new__(
        cls,
        filter_description: str | bytes,
        in_stream: Stream | Codec | str | None = None,
        out_stream: Stream | None = None,
    ) -> Self: ...
    def filter(self, packet: Packet[Any] | None) -> list[Packet[Stream]]: ...
    def flush(self) -> None: ...

bitstream_filters_available: set[str]
