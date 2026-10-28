from typing import Any, Literal, final, override

from av.codec.context import CodecContext
from av.packet import Packet
from av.stream import Stream
from av.subtitles.subtitle import AssSubtitle, BitmapSubtitle, SubtitleSet

@final
class SubtitleCodecContext(CodecContext):
    type: Literal["subtitle"]
    subtitle_header: bytes | None
    @override
    def decode(
        self, packet: Packet[Any] | None = None
    ) -> list[AssSubtitle] | list[BitmapSubtitle]: ...
    def decode2(self, packet: Packet[Any]) -> SubtitleSet | None: ...
    def encode_subtitle(self, subtitle: SubtitleSet) -> Packet[Stream]: ...
