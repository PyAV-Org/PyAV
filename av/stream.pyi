from enum import Flag
from fractions import Fraction
from typing import Literal

from .codec import Codec, CodecContext
from .container import Container

class Disposition(Flag):
    default: int
    dub: int
    original: int
    comment: int
    lyrics: int
    karaoke: int
    forced: int
    hearing_impaired: int
    visual_impaired: int
    clean_effects: int
    attached_pic: int
    timed_thumbnails: int
    non_diegetic: int
    captions: int
    descriptions: int
    metadata: int
    dependent: int
    still_image: int
    multilayer: int

class Stream:
    name: str | None
    container: Container
    codec: Codec
    codec_context: CodecContext
    metadata: dict[str, str]
    id: int
    profiles: list[str]
    profile: str | None
    index: int
    time_base: Fraction | None
    average_rate: Fraction | None
    base_rate: Fraction | None
    guessed_rate: Fraction | None
    start_time: int | None
    duration: int | None
    disposition: Disposition
    frames: int
    language: str | None
    type: Literal["video", "audio", "data", "subtitle", "attachment"]
