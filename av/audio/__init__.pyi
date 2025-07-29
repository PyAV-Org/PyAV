from typing import Literal

from .frame import AudioFrame
from .stream import AudioStream

_AudioCodecName = Literal[
    "aac",
    "libopus",
    "mp2",
    "mp3",
    "pcm_alaw",
    "pcm_mulaw",
    "pcm_s16le",
]

__all__ = ("AudioFrame", "AudioStream")
