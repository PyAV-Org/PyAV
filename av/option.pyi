from av.enum import EnumFlag, EnumItem

class OptionType(EnumItem):
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

class OptionFlags(EnumFlag):
    ENCODING_PARAM: int
    DECODING_PARAM: int
    AUDIO_PARAM: int
    VIDEO_PARAM: int
    SUBTITLE_PARAM: int
    EXPORT: int
    READONLY: int
    FILTERING_PARAM: int
