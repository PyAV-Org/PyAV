from av.frame import Frame
from av.packet import Packet
from av.stream import Stream

class DataStream(Stream):
    name: str | None
