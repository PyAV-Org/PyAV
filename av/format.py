from enum import Flag

import cython
import cython.cimports.libav as lib
from cython.cimports.av.descriptor import wrap_avclass

_cinit_bypass_sentinel = cython.declare(object, object())


@cython.cfunc
def build_container_format(
    iptr: cython.pointer[cython.const[lib.AVInputFormat]],
    optr: cython.pointer[cython.const[lib.AVOutputFormat]],
) -> ContainerFormat:
    if not iptr and not optr:
        raise ValueError("needs input format or output format")
    format: ContainerFormat = ContainerFormat.__new__(
        ContainerFormat, _cinit_bypass_sentinel
    )
    format.iptr = iptr
    format.optr = optr
    format.name = optr.name if optr else iptr.name
    return format


# fmt: off
class Flags(Flag):
    no_file = lib.AVFMT_NOFILE
    need_number: "Needs '%d' in filename." = lib.AVFMT_NEEDNUMBER
    show_ids: "Show format stream IDs numbers." = lib.AVFMT_SHOW_IDS
    global_header: "Format wants global header." = lib.AVFMT_GLOBALHEADER
    no_timestamps: "Format does not need / have any timestamps." = lib.AVFMT_NOTIMESTAMPS
    generic_index: "Use generic index building code." = lib.AVFMT_GENERIC_INDEX
    ts_discont: "Format allows timestamp discontinuities" = lib.AVFMT_TS_DISCONT
    variable_fps: "Format allows variable fps." = lib.AVFMT_VARIABLE_FPS
    no_dimensions: "Format does not need width/height" = lib.AVFMT_NODIMENSIONS
    no_streams: "Format does not require any streams" = lib.AVFMT_NOSTREAMS
    no_bin_search: "Format does not allow to fall back on binary search via read_timestamp" = lib.AVFMT_NOBINSEARCH
    no_gen_search: "Format does not allow to fall back on generic search" = lib.AVFMT_NOGENSEARCH
    no_byte_seek: "Format does not allow seeking by bytes" = lib.AVFMT_NO_BYTE_SEEK
    ts_nonstrict: "Format does not require strictly increasing timestamps, but they must still be monotonic." = lib.AVFMT_TS_NONSTRICT
    ts_negative: "Format allows muxing negative timestamps." = lib.AVFMT_TS_NEGATIVE
    # If not set the timestamp will be shifted in `av_write_frame()` and `av_interleaved_write_frame()`
    # so they start from 0. The user or muxer can override this through AVFormatContext.avoid_negative_ts
    seek_to_pts: "Seeking is based on PTS" = lib.AVFMT_SEEK_TO_PTS
# fmt: on


@cython.cclass
class ContainerFormat:
    """Descriptor of a container format.

    :param str name: The name of the format.
    :param str mode: ``'r'`` or ``'w'`` for input and output formats; defaults
        to None which will grab either.

    """

    def __cinit__(self, name, mode=None):
        if name is _cinit_bypass_sentinel:
            return

        # We need to hold onto the original name because AVInputFormat.name is
        # actually comma-separated, and so we need to remember which one this was.
        self.name = name

        # Searches comma-separated names.
        if mode is None or mode == "r":
            self.iptr = lib.av_find_input_format(name)

        if mode is None or mode == "w":
            self.optr = lib.av_guess_format(name, cython.NULL, cython.NULL)

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
        if self.iptr == cython.NULL:
            return None
        elif self.optr == cython.NULL:
            return self
        else:
            return build_container_format(self.iptr, cython.NULL)

    @property
    def output(self):
        """An output-only view of this format."""
        if self.optr == cython.NULL:
            return None
        elif self.iptr == cython.NULL:
            return self
        else:
            return build_container_format(cython.NULL, self.optr)

    @property
    def is_input(self):
        return self.iptr != cython.NULL

    @property
    def is_output(self):
        return self.optr != cython.NULL

    @property
    def long_name(self):
        # We prefer the output names since the inputs may represent
        # multiple formats.
        return self.optr.long_name if self.optr else self.iptr.long_name

    @property
    def extensions(self):
        exts: set = set()
        if self.iptr and self.iptr.extensions:
            exts.update(self.iptr.extensions.split(","))
        if self.optr and self.optr.extensions:
            exts.update(self.optr.extensions.split(","))
        return exts

    @property
    def flags(self):
        """
        Get the flags bitmask for the format.

        :rtype: int
        """
        return (self.iptr.flags if self.iptr else 0) | (
            self.optr.flags if self.optr else 0
        )

    @property
    def no_file(self):
        return bool(self.flags & lib.AVFMT_NOFILE)


@cython.cfunc
def get_output_format_names() -> set:
    names: set = set()
    ptr: cython.pointer[cython.const[lib.AVOutputFormat]]
    opaque: cython.p_void = cython.NULL
    while True:
        ptr = lib.av_muxer_iterate(cython.address(opaque))
        if ptr:
            names.add(ptr.name)
        else:
            break
    return names


@cython.cfunc
def get_input_format_names() -> set:
    names: set = set()
    ptr: cython.pointer[cython.const[lib.AVInputFormat]]
    opaque: cython.p_void = cython.NULL
    while True:
        ptr = lib.av_demuxer_iterate(cython.address(opaque))
        if ptr:
            names.add(ptr.name)
        else:
            break
    return names


formats_available = get_output_format_names()
formats_available.update(get_input_format_names())
format_descriptor = wrap_avclass(lib.avformat_get_class())
