from typing import Literal

# FFmpeg 9.0 encoders and the codec descriptor aliases that resolve to them.
_SubtitleCodecName = Literal[
    "ass",
    "dvb_subtitle",
    "dvbsub",
    "dvd_subtitle",
    "dvdsub",
    "mov_text",
    "srt",
    "ssa",
    "subrip",
    "text",
    "ttml",
    "webvtt",
    "xsub",
]
