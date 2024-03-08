from typing import Literal

from av.codec.context import CodecContext

from .format import AudioFormat
from .layout import AudioLayout

class AudioCodecContext(CodecContext):
    frame_size: int
    sample_rate: int
    rate: int
    channels: int
    channel_layout: int
    layout: AudioLayout
    format: AudioFormat
    type: Literal["audio"]
