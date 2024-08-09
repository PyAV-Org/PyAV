from typing import Literal

from av.codec.context import CodecContext

class AttachmentCodecContext(CodecContext):
    type: Literal["attachment"]
