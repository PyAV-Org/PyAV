from fractions import Fraction
from typing import Sequence

from av.packet import Packet
from av.stream import Stream

from .core import Container

class OutputContainer(Container):
    def __enter__(self) -> OutputContainer: ...
    def add_stream(
        self,
        codec_name: str,
        rate: Fraction | int | float,
        template: Stream,
        options: dict[str, str],
    ) -> Stream: ...
    def start_encoding(self) -> None: ...
    def close(self) -> None: ...
    def mux(self, packets: Sequence[Packet]) -> None: ...
    def mux_one(self, packet: Packet) -> None: ...
