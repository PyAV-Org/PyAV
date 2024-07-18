from av.packet import Packet
from av.stream import Stream
from av.subtitles.subtitle import SubtitleSet

class SubtitleStream(Stream):
    def decode(self, packet: Packet | None = None) -> list[SubtitleSet]: ...
