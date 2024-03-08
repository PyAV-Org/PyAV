from av.frame import Frame
from av.packet import Packet
from av.stream import Stream

class DataStream(Stream):
    def encode(self, frame: Frame | None = None) -> list[Packet]: ...
    def decode(self, packet: Packet | None = None, count: int = 0) -> list[Frame]: ...
