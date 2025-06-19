from typing import Literal

from av.codec.context import CodecContext
from av.packet import Packet
from av.subtitles.subtitle import SubtitleSet

class SubtitleCodecContext(CodecContext):
    type: Literal["subtitle"]
    def decode2(self, packet: Packet) -> SubtitleSet | None: ...
