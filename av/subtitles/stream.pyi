from typing import final

from av.codec.codec import Codec
from av.packet import Packet
from av.stream import Stream
from av.subtitles.subtitle import AssSubtitle, BitmapSubtitle, SubtitleSet

from .codeccontext import SubtitleCodecContext

@final
class SubtitleStream(Stream):
    codec_context: SubtitleCodecContext

    # From codec context
    codec: Codec
    codec_tag: str
    options: dict[str, str]
    def decode(
        self, packet: Packet | None = None
    ) -> list[AssSubtitle] | list[BitmapSubtitle]: ...
    def decode2(self, packet: Packet) -> SubtitleSet | None: ...
