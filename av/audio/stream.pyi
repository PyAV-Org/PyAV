from av.packet import Packet
from av.stream import Stream

from .format import AudioFormat
from .frame import AudioFrame

class AudioStream(Stream):
    format: AudioFormat
    type = "audio"

    def encode(self, frame: AudioFrame | None = None) -> list[Packet]: ...
    def decode(self, packet: Packet | None = None) -> list[AudioFrame]: ...
