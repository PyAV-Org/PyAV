import cython
from cython.cimports.cpython import PyBuffer_FillInfo, PyBytes_FromString
from cython.cimports.libc.stdint import uint64_t


@cython.cclass
class SubtitleProxy:
    def __dealloc__(self):
        lib.avsubtitle_free(cython.address(self.struct))


@cython.cclass
class SubtitleSet:
    """
    A :class:`SubtitleSet` can contain many :class:`Subtitle` objects.

    Wraps :ffmpeg:`AVSubtitle`.
    """

    def __cinit__(self, proxy: SubtitleProxy):
        self.proxy = proxy
        self.rects = tuple(
            build_subtitle(self, i) for i in range(self.proxy.struct.num_rects)
        )

    def __repr__(self):
        return (
            f"<{self.__class__.__module__}.{self.__class__.__name__} at 0x{id(self):x}>"
        )

    @property
    def format(self):
        return self.proxy.struct.format

    @property
    def start_display_time(self):
        return self.proxy.struct.start_display_time

    @property
    def end_display_time(self):
        return self.proxy.struct.end_display_time

    @property
    def pts(self):
        """Same as packet pts, in av.time_base."""
        return self.proxy.struct.pts

    def __len__(self):
        return len(self.rects)

    def __iter__(self):
        return iter(self.rects)

    def __getitem__(self, i):
        return self.rects[i]


@cython.cfunc
def build_subtitle(subtitle: SubtitleSet, index: cython.int) -> Subtitle:
    """Build an av.Stream for an existing AVStream.

    The AVStream MUST be fully constructed and ready for use before this is called.
    """
    if index < 0 or cython.cast(cython.uint, index) >= subtitle.proxy.struct.num_rects:
        raise ValueError("subtitle rect index out of range")

    ptr: cython.pointer[lib.AVSubtitleRect] = subtitle.proxy.struct.rects[index]

    if ptr.type == lib.SUBTITLE_BITMAP:
        return BitmapSubtitle(subtitle, index)
    if ptr.type == lib.SUBTITLE_ASS or ptr.type == lib.SUBTITLE_TEXT:
        return AssSubtitle(subtitle, index)

    raise ValueError("unknown subtitle type %r" % ptr.type)


@cython.cclass
class Subtitle:
    """
    An abstract base class for each concrete type of subtitle.
    Wraps :ffmpeg:`AVSubtitleRect`
    """

    def __cinit__(self, subtitle: SubtitleSet, index: cython.int):
        if (
            index < 0
            or cython.cast(cython.uint, index) >= subtitle.proxy.struct.num_rects
        ):
            raise ValueError("subtitle rect index out of range")
        self.proxy = subtitle.proxy
        self.ptr = self.proxy.struct.rects[index]

        if self.ptr.type == lib.SUBTITLE_NONE:
            self.type = b"none"
        elif self.ptr.type == lib.SUBTITLE_BITMAP:
            self.type = b"bitmap"
        elif self.ptr.type == lib.SUBTITLE_TEXT:
            self.type = b"text"
        elif self.ptr.type == lib.SUBTITLE_ASS:
            self.type = b"ass"
        else:
            raise ValueError(f"unknown subtitle type {self.ptr.type!r}")

    def __repr__(self):
        return f"<av.{self.__class__.__name__} at 0x{id(self):x}>"


@cython.cclass
class BitmapSubtitle(Subtitle):
    def __cinit__(self, subtitle: SubtitleSet, index: cython.int):
        self.planes = tuple(
            BitmapSubtitlePlane(self, i) for i in range(4) if self.ptr.linesize[i]
        )

    def __repr__(self):
        return (
            f"<{self.__class__.__module__}.{self.__class__.__name__} "
            f"{self.width}x{self.height} at {self.x},{self.y}; at 0x{id(self):x}>"
        )

    @property
    def x(self):
        return self.ptr.x

    @property
    def y(self):
        return self.ptr.y

    @property
    def width(self):
        return self.ptr.w

    @property
    def height(self):
        return self.ptr.h

    @property
    def nb_colors(self):
        return self.ptr.nb_colors

    def __len__(self):
        return len(self.planes)

    def __iter__(self):
        return iter(self.planes)

    def __getitem__(self, i):
        return self.planes[i]


@cython.cclass
class BitmapSubtitlePlane:
    def __cinit__(self, subtitle: BitmapSubtitle, index: cython.int):
        if index >= 4:
            raise ValueError("BitmapSubtitles have only 4 planes")
        if not subtitle.ptr.linesize[index]:
            raise ValueError("plane does not exist")

        self.subtitle = subtitle
        self.index = index
        self.buffer_size = subtitle.ptr.w * subtitle.ptr.h
        self._buffer = cython.cast(cython.p_void, subtitle.ptr.data[index])

    # New-style buffer support.
    def __getbuffer__(self, view: cython.pointer[Py_buffer], flags: cython.int):
        PyBuffer_FillInfo(view, self, self._buffer, self.buffer_size, 0, flags)


@cython.cclass
class AssSubtitle(Subtitle):
    """
    Represents an ASS/Text subtitle format, as opposed to a bitmap Subtitle format.
    """

    def __repr__(self):
        return f"<av.AssSubtitle {self.dialogue!r} at 0x{id(self):x}>"

    @property
    def ass(self):
        """
        Returns the subtitle in the ASS/SSA format. Used by the vast majority of subtitle formats.
        """
        if self.ptr.ass is not cython.NULL:
            return PyBytes_FromString(self.ptr.ass)
        return b""

    @property
    def dialogue(self):
        """
        Extract the dialogue from the ass format. Strip comments.
        """
        comma_count: cython.short = 0
        i: uint64_t = 0
        state: cython.bint = False
        ass_text: bytes = self.ass
        char, next_char = cython.declare(cython.char)
        result: bytearray = bytearray()
        text_len: cython.Py_ssize_t = len(ass_text)

        while comma_count < 8 and i < text_len:
            if ass_text[i] == b","[0]:
                comma_count += 1
            i += 1

        while i < text_len:
            char = ass_text[i]
            next_char = 0 if i + 1 >= text_len else ass_text[i + 1]

            if char == b"\\"[0] and next_char == b"N"[0]:
                result.append(b"\n"[0])
                i += 2
                continue

            if not state:
                if char == b"{"[0] and next_char != b"\\"[0]:
                    state = True
                else:
                    result.append(char)
            elif char == b"}"[0]:
                state = False
            i += 1

        return bytes(result)

    @property
    def text(self):
        """
        Rarely used attribute. You're probably looking for dialogue.
        """
        if self.ptr.text is not cython.NULL:
            return PyBytes_FromString(self.ptr.text)
        return b""
