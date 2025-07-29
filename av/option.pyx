cimport libav as lib

from av.utils cimport flag_in_bitfield

from enum import Enum, Flag


cdef object _cinit_sentinel = object()

cdef Option wrap_option(tuple choices, const lib.AVOption *ptr):
    if ptr == NULL:
        return None
    cdef Option obj = Option(_cinit_sentinel)
    obj.ptr = ptr
    obj.choices = choices
    return obj


class OptionType(Enum):
    FLAGS = lib.AV_OPT_TYPE_FLAGS
    INT = lib.AV_OPT_TYPE_INT
    INT64 = lib.AV_OPT_TYPE_INT64
    DOUBLE = lib.AV_OPT_TYPE_DOUBLE
    FLOAT = lib.AV_OPT_TYPE_FLOAT
    STRING = lib.AV_OPT_TYPE_STRING
    RATIONAL = lib.AV_OPT_TYPE_RATIONAL
    BINARY = lib.AV_OPT_TYPE_BINARY
    DICT = lib.AV_OPT_TYPE_DICT
    UINT64 = lib.AV_OPT_TYPE_UINT64
    CONST = lib.AV_OPT_TYPE_CONST
    IMAGE_SIZE = lib.AV_OPT_TYPE_IMAGE_SIZE
    PIXEL_FMT = lib.AV_OPT_TYPE_PIXEL_FMT
    SAMPLE_FMT = lib.AV_OPT_TYPE_SAMPLE_FMT
    VIDEO_RATE = lib.AV_OPT_TYPE_VIDEO_RATE
    DURATION = lib.AV_OPT_TYPE_DURATION
    COLOR = lib.AV_OPT_TYPE_COLOR
    CHANNEL_LAYOUT = lib.AV_OPT_TYPE_CHLAYOUT
    BOOL = lib.AV_OPT_TYPE_BOOL

cdef tuple _INT_TYPES = (
    lib.AV_OPT_TYPE_FLAGS,
    lib.AV_OPT_TYPE_INT,
    lib.AV_OPT_TYPE_INT64,
    lib.AV_OPT_TYPE_PIXEL_FMT,
    lib.AV_OPT_TYPE_SAMPLE_FMT,
    lib.AV_OPT_TYPE_DURATION,
    lib.AV_OPT_TYPE_CHLAYOUT,
    lib.AV_OPT_TYPE_BOOL,
)

class OptionFlags(Flag):
    ENCODING_PARAM = lib.AV_OPT_FLAG_ENCODING_PARAM
    DECODING_PARAM = lib.AV_OPT_FLAG_DECODING_PARAM
    AUDIO_PARAM = lib.AV_OPT_FLAG_AUDIO_PARAM
    VIDEO_PARAM = lib.AV_OPT_FLAG_VIDEO_PARAM
    SUBTITLE_PARAM = lib.AV_OPT_FLAG_SUBTITLE_PARAM
    EXPORT = lib.AV_OPT_FLAG_EXPORT
    READONLY = lib.AV_OPT_FLAG_READONLY
    FILTERING_PARAM = lib.AV_OPT_FLAG_FILTERING_PARAM


cdef class BaseOption:
    def __cinit__(self, sentinel):
        if sentinel is not _cinit_sentinel:
            raise RuntimeError(f"Cannot construct av.{self.__class__.__name__}")

    @property
    def name(self):
        return self.ptr.name

    @property
    def help(self):
        return self.ptr.help if self.ptr.help != NULL else ""

    @property
    def flags(self):
        return self.ptr.flags

    # Option flags
    @property
    def is_encoding_param(self):
        return flag_in_bitfield(self.ptr.flags, lib.AV_OPT_FLAG_ENCODING_PARAM)
    @property
    def is_decoding_param(self):
        return flag_in_bitfield(self.ptr.flags, lib.AV_OPT_FLAG_DECODING_PARAM)
    @property
    def is_audio_param(self):
        return flag_in_bitfield(self.ptr.flags, lib.AV_OPT_FLAG_AUDIO_PARAM)
    @property
    def is_video_param(self):
        return flag_in_bitfield(self.ptr.flags, lib.AV_OPT_FLAG_VIDEO_PARAM)
    @property
    def is_subtitle_param(self):
        return flag_in_bitfield(self.ptr.flags, lib.AV_OPT_FLAG_SUBTITLE_PARAM)
    @property
    def is_export(self):
        return flag_in_bitfield(self.ptr.flags, lib.AV_OPT_FLAG_EXPORT)
    @property
    def is_readonly(self):
        return flag_in_bitfield(self.ptr.flags, lib.AV_OPT_FLAG_READONLY)
    @property
    def is_filtering_param(self):
        return flag_in_bitfield(self.ptr.flags, lib.AV_OPT_FLAG_FILTERING_PARAM)


cdef class Option(BaseOption):
    @property
    def type(self):
        return OptionType(self.ptr.type)

    @property
    def offset(self):
        """
        This can be used to find aliases of an option.
        Options in a particular descriptor with the same offset are aliases.
        """
        return self.ptr.offset

    @property
    def default(self):
        if self.ptr.type in _INT_TYPES:
            return self.ptr.default_val.i64
        if self.ptr.type in (lib.AV_OPT_TYPE_DOUBLE, lib.AV_OPT_TYPE_FLOAT,
                             lib.AV_OPT_TYPE_RATIONAL):
            return self.ptr.default_val.dbl
        if self.ptr.type in (lib.AV_OPT_TYPE_STRING, lib.AV_OPT_TYPE_BINARY,
                             lib.AV_OPT_TYPE_IMAGE_SIZE, lib.AV_OPT_TYPE_VIDEO_RATE,
                             lib.AV_OPT_TYPE_COLOR):
            return self.ptr.default_val.str if self.ptr.default_val.str != NULL else ""

    def _norm_range(self, value):
        if self.ptr.type in _INT_TYPES:
            return int(value)
        return value

    @property
    def min(self):
        return self._norm_range(self.ptr.min)

    @property
    def max(self):
        return self._norm_range(self.ptr.max)

    def __repr__(self):
        return (
            f"<av.{self.__class__.__name__} {self.name}"
            f" ({self.type} at *0x{self.offset:x}) at 0x{id(self):x}>"
        )


cdef OptionChoice wrap_option_choice(const lib.AVOption *ptr, bint is_default):
    if ptr == NULL:
        return None

    cdef OptionChoice obj = OptionChoice(_cinit_sentinel)
    obj.ptr = ptr
    obj.is_default = is_default
    return obj


cdef class OptionChoice(BaseOption):
    """
    Represents AV_OPT_TYPE_CONST options which are essentially
    choices of non-const option with same unit.
    """

    @property
    def value(self):
        return self.ptr.default_val.i64

    def __repr__(self):
        return f"<av.{self.__class__.__name__} {self.name} at 0x{id(self):x}>"
