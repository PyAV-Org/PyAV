from typing import Literal

from av.codec.context import CodecContext
from av.packet import Packet
from av.subtitles.subtitle import SubtitleSet

class SubtitleCodecContext(CodecContext):
    type: Literal["subtitle"]
    subtitle_header: bytes | None
    def decode2(self, packet: Packet) -> SubtitleSet | None: ...
    def encode_subtitle(self, subtitle: SubtitleSet) -> Packet: ...
