from enum import IntEnum, IntFlag
from fractions import Fraction
from typing import Literal, cast, final

from av.rational import AVRational

from .codec import CodecContext
from .container import Container
from .index import IndexEntries

class Disposition(IntFlag):
    default = cast(int, ...)
    dub = cast(int, ...)
    original = cast(int, ...)
    comment = cast(int, ...)
    lyrics = cast(int, ...)
    karaoke = cast(int, ...)
    forced = cast(int, ...)
    hearing_impaired = cast(int, ...)
    visual_impaired = cast(int, ...)
    clean_effects = cast(int, ...)
    attached_pic = cast(int, ...)
    timed_thumbnails = cast(int, ...)
    non_diegetic = cast(int, ...)
    captions = cast(int, ...)
    descriptions = cast(int, ...)
    metadata = cast(int, ...)
    dependent = cast(int, ...)
    still_image = cast(int, ...)
    multilayer = cast(int, ...)

class Discard(IntEnum):
    none = cast(int, ...)
    default = cast(int, ...)
    nonref = cast(int, ...)
    bidir = cast(int, ...)
    nonintra = cast(int, ...)
    nonkey = cast(int, ...)
    all = cast(int, ...)

class Stream:
    name: str | None
    container: Container
    codec_context: CodecContext | None
    metadata: dict[str, str]
    @property
    def index_entries(self) -> IndexEntries: ...
    id: int
    profiles: list[str]
    profile: str | None
    index: int
    @property
    def time_base(self) -> AVRational: ...
    @time_base.setter
    def time_base(self, value: AVRational | Fraction | int) -> None: ...
    start_time: int | None
    duration: int | None
    disposition: Disposition
    discard: Discard
    frames: int
    language: str | None
    type: Literal["video", "audio", "data", "subtitle", "attachment", "unknown"]

@final
class DataStream(Stream):
    codec_context: None
    type: Literal["data"]
    name: str | None

@final
class AttachmentStream(Stream):
    codec_context: None
    type: Literal["attachment"]
    @property
    def mimetype(self) -> str | None: ...
    @property
    def data(self) -> bytes: ...
