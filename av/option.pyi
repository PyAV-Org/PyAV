from enum import Enum, Flag

class OptionType(Enum):
    FLAGS: int
    INT: int
    INT64: int
    DOUBLE: int
    FLOAT: int
    STRING: int
    RATIONAL: int
    BINARY: int
    DICT: int
    CONST: int
    IMAGE_SIZE: int
    PIXEL_FMT: int
    SAMPLE_FMT: int
    VIDEO_RATE: int
    DURATION: int
    COLOR: int
    CHANNEL_LAYOUT: int
    BOOL: int

class OptionFlags(Flag):
    ENCODING_PARAM: int
    DECODING_PARAM: int
    AUDIO_PARAM: int
    VIDEO_PARAM: int
    SUBTITLE_PARAM: int
    EXPORT: int
    READONLY: int
    FILTERING_PARAM: int

class BaseOption:
    name: str
    help: str
    flags: int
    is_encoding_param: bool
    is_decoding_param: bool
    is_audio_param: bool
    is_video_param: bool
    is_subtitle_param: bool
    is_export: bool
    is_readonly: bool
    is_filtering_param: bool

class Option(BaseOption):
    type: OptionType
    offset: int
    default: int
    min: int
    max: int

class OptionChoice(BaseOption):
    value: int
