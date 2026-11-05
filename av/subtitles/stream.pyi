from typing import Any, final

from av.codec.codec import Codec
from av.packet import Packet
from av.stream import Stream
from av.subtitles.subtitle import AssSubtitle, BitmapSubtitle, SubtitleSet

from .codeccontext import SubtitleCodecContext

@final
class SubtitleStream(Stream):
    @property
    def cctx(self) -> SubtitleCodecContext: ...
    @property
    def codec_context(self) -> SubtitleCodecContext: ...

    # From codec context
    @property
    def name(self) -> str: ...
    @property
    def codec(self) -> Codec: ...
    codec_tag: str
    options: dict[str, str]
    def decode(
        self, packet: Packet[Any] | None = None
    ) -> list[AssSubtitle] | list[BitmapSubtitle]: ...
    def decode2(self, packet: Packet[Any]) -> SubtitleSet | None: ...
