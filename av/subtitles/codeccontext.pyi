from typing import Literal

from av.codec.context import CodecContext

class SubtitleCodecContext(CodecContext):
    type: Literal["subtitle"]
