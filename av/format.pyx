cimport libav as lib

from av.descriptor cimport wrap_avclass
from av.enum cimport define_enum


cdef object _cinit_bypass_sentinel = object()

cdef ContainerFormat build_container_format(lib.AVInputFormat* iptr, lib.AVOutputFormat* optr):
    if not iptr and not optr:
        raise ValueError("needs input format or output format")
    cdef ContainerFormat format = ContainerFormat.__new__(ContainerFormat, _cinit_bypass_sentinel)
    format.iptr = iptr
    format.optr = optr
    format.name = optr.name if optr else iptr.name
    return format


Flags = define_enum("Flags", __name__, (
    ("NOFILE", lib.AVFMT_NOFILE),
    ("NEEDNUMBER", lib.AVFMT_NEEDNUMBER, "Needs '%d' in filename."),
    ("SHOW_IDS", lib.AVFMT_SHOW_IDS, "Show format stream IDs numbers."),
    ("GLOBALHEADER", lib.AVFMT_GLOBALHEADER, "Format wants global header."),
    ("NOTIMESTAMPS", lib.AVFMT_NOTIMESTAMPS, "Format does not need / have any timestamps."),
    ("GENERIC_INDEX", lib.AVFMT_GENERIC_INDEX, "Use generic index building code."),
    ("TS_DISCONT", lib.AVFMT_TS_DISCONT,
        """Format allows timestamp discontinuities.
        Note, muxers always require valid (monotone) timestamps"""),
    ("VARIABLE_FPS", lib.AVFMT_VARIABLE_FPS, "Format allows variable fps."),
    ("NODIMENSIONS", lib.AVFMT_NODIMENSIONS, "Format does not need width/height"),
    ("NOSTREAMS", lib.AVFMT_NOSTREAMS, "Format does not require any streams"),
    ("NOBINSEARCH", lib.AVFMT_NOBINSEARCH,
        "Format does not allow to fall back on binary search via read_timestamp"),
    ("NOGENSEARCH", lib.AVFMT_NOGENSEARCH,
        "Format does not allow to fall back on generic search"),
    ("NO_BYTE_SEEK", lib.AVFMT_NO_BYTE_SEEK, "Format does not allow seeking by bytes"),
    ("ALLOW_FLUSH", lib.AVFMT_ALLOW_FLUSH,
        """Format allows flushing. If not set, the muxer will not receive a NULL
        packet in the write_packet function."""),
    ("TS_NONSTRICT", lib.AVFMT_TS_NONSTRICT,
        """Format does not require strictly increasing timestamps, but they must
        still be monotonic."""),
    ("TS_NEGATIVE", lib.AVFMT_TS_NEGATIVE,
        """Format allows muxing negative timestamps. If not set the timestamp
        will be shifted in av_write_frame and av_interleaved_write_frame so they
        start from 0. The user or muxer can override this through
        AVFormatContext.avoid_negative_ts"""),
    ("SEEK_TO_PTS", lib.AVFMT_SEEK_TO_PTS, "Seeking is based on PTS"),
), is_flags=True)


cdef class ContainerFormat:

    """Descriptor of a container format.

    :param str name: The name of the format.
    :param str mode: ``'r'`` or ``'w'`` for input and output formats; defaults
        to None which will grab either.

    """

    def __cinit__(self, name, mode=None):
        if name is _cinit_bypass_sentinel:
            return

        # We need to hold onto the original name because AVInputFormat.name
        # is actually comma-seperated, and so we need to remember which one
        # this was.
        self.name = name

        # Searches comma-seperated names.
        if mode is None or mode == "r":
            self.iptr = lib.av_find_input_format(name)

        if mode is None or mode == "w":
            self.optr = lib.av_guess_format(name, NULL, NULL)

        if not self.iptr and not self.optr:
            raise ValueError(f"no container format {name!r}")

    def __repr__(self):
        return f"<av.{self.__class__.__name__} {self.name!r}>"

    @property
    def descriptor(self):
        if self.iptr:
            return wrap_avclass(self.iptr.priv_class)
        else:
            return wrap_avclass(self.optr.priv_class)

    @property
    def options(self):
        return self.descriptor.options

    @property
    def input(self):
        """An input-only view of this format."""
        if self.iptr == NULL:
            return None
        elif self.optr == NULL:
            return self
        else:
            return build_container_format(self.iptr, NULL)

    @property
    def output(self):
        """An output-only view of this format."""
        if self.optr == NULL:
            return None
        elif self.iptr == NULL:
            return self
        else:
            return build_container_format(NULL, self.optr)

    @property
    def is_input(self):
        return self.iptr != NULL

    @property
    def is_output(self):
        return self.optr != NULL

    @property
    def long_name(self):
        # We prefer the output names since the inputs may represent
        # multiple formats.
        return self.optr.long_name if self.optr else self.iptr.long_name

    @property
    def extensions(self):
        cdef set exts = set()
        if self.iptr and self.iptr.extensions:
            exts.update(self.iptr.extensions.split(","))
        if self.optr and self.optr.extensions:
            exts.update(self.optr.extensions.split(","))
        return exts

    @Flags.property
    def flags(self):
        return (
            (self.iptr.flags if self.iptr else 0) |
            (self.optr.flags if self.optr else 0)
        )

    no_file = flags.flag_property("NOFILE")
    need_number = flags.flag_property("NEEDNUMBER")
    show_ids = flags.flag_property("SHOW_IDS")
    global_header = flags.flag_property("GLOBALHEADER")
    no_timestamps = flags.flag_property("NOTIMESTAMPS")
    generic_index = flags.flag_property("GENERIC_INDEX")
    ts_discont = flags.flag_property("TS_DISCONT")
    variable_fps = flags.flag_property("VARIABLE_FPS")
    no_dimensions = flags.flag_property("NODIMENSIONS")
    no_streams = flags.flag_property("NOSTREAMS")
    no_bin_search = flags.flag_property("NOBINSEARCH")
    no_gen_search = flags.flag_property("NOGENSEARCH")
    no_byte_seek = flags.flag_property("NO_BYTE_SEEK")
    allow_flush = flags.flag_property("ALLOW_FLUSH")
    ts_nonstrict = flags.flag_property("TS_NONSTRICT")
    ts_negative = flags.flag_property("TS_NEGATIVE")
    seek_to_pts = flags.flag_property("SEEK_TO_PTS")


cdef get_output_format_names():
    names = set()
    cdef const lib.AVOutputFormat *ptr
    cdef void *opaque = NULL
    while True:
        ptr = lib.av_muxer_iterate(&opaque)
        if ptr:
            names.add(ptr.name)
        else:
            break
    return names

cdef get_input_format_names():
    names = set()
    cdef const lib.AVInputFormat *ptr
    cdef void *opaque = NULL
    while True:
        ptr = lib.av_demuxer_iterate(&opaque)
        if ptr:
            names.add(ptr.name)
        else:
            break
    return names

formats_available = get_output_format_names()
formats_available.update(get_input_format_names())


format_descriptor = wrap_avclass(lib.avformat_get_class())
