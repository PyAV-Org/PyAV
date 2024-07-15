from cpython cimport PyBuffer_FillInfo


cdef extern from "Python.h":
    bytes PyBytes_FromString(char*)


cdef class SubtitleProxy:
    def __dealloc__(self):
        lib.avsubtitle_free(&self.struct)


cdef class SubtitleSet:
    """
    A :class:`SubtitleSet` can contain many :class:`Subtitle` objects.
    """
    def __cinit__(self, SubtitleProxy proxy):
        self.proxy = proxy
        cdef int i
        self.rects = tuple(build_subtitle(self, i) for i in range(self.proxy.struct.num_rects))

    def __repr__(self):
        return f"<{self.__class__.__module__}.{self.__class__.__name__} at 0x{id(self):x}>"

    @property
    def format(self): return self.proxy.struct.format
    @property
    def start_display_time(self): return self.proxy.struct.start_display_time
    @property
    def end_display_time(self): return self.proxy.struct.end_display_time
    @property
    def pts(self): return self.proxy.struct.pts

    def __len__(self):
        return len(self.rects)

    def __iter__(self):
        return iter(self.rects)

    def __getitem__(self, i):
        return self.rects[i]


cdef Subtitle build_subtitle(SubtitleSet subtitle, int index):
    """Build an av.Stream for an existing AVStream.

    The AVStream MUST be fully constructed and ready for use before this is
    called.

    """

    if index < 0 or <unsigned int>index >= subtitle.proxy.struct.num_rects:
        raise ValueError("subtitle rect index out of range")
    cdef lib.AVSubtitleRect *ptr = subtitle.proxy.struct.rects[index]

    if ptr.type == lib.SUBTITLE_BITMAP:
        return BitmapSubtitle(subtitle, index)
    elif ptr.type == lib.SUBTITLE_ASS or ptr.type == lib.SUBTITLE_TEXT:
        return AssSubtitle(subtitle, index)
    else:
        raise ValueError("unknown subtitle type %r" % ptr.type)


cdef class Subtitle:
    """
    An abstract base class for each concrete type of subtitle.
    Wraps :ffmpeg:`AVSubtitleRect`
    """
    def __cinit__(self, SubtitleSet subtitle, int index):
        if index < 0 or <unsigned int>index >= subtitle.proxy.struct.num_rects:
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
        return f"<{self.__class__.__module__}.{self.__class__.__name__} at 0x{id(self):x}>"


cdef class BitmapSubtitle(Subtitle):
    def __cinit__(self, SubtitleSet subtitle, int index):
        self.planes = tuple(
            BitmapSubtitlePlane(self, i)
            for i in range(4)
            if self.ptr.linesize[i]
        )

    def __repr__(self):
        return (
            f"<{self.__class__.__module__}.{self.__class__.__name__} "
            f"{self.width}x{self.height} at {self.x},{self.y}; at 0x{id(self):x}>"
        )

    @property
    def x(self): return self.ptr.x
    @property
    def y(self): return self.ptr.y
    @property
    def width(self): return self.ptr.w
    @property
    def height(self): return self.ptr.h
    @property
    def nb_colors(self): return self.ptr.nb_colors

    def __len__(self):
        return len(self.planes)

    def __iter__(self):
        return iter(self.planes)

    def __getitem__(self, i):
        return self.planes[i]


cdef class BitmapSubtitlePlane:
    def __cinit__(self, BitmapSubtitle subtitle, int index):
        if index >= 4:
            raise ValueError("BitmapSubtitles have only 4 planes")
        if not subtitle.ptr.linesize[index]:
            raise ValueError("plane does not exist")

        self.subtitle = subtitle
        self.index = index
        self.buffer_size = subtitle.ptr.w * subtitle.ptr.h
        self._buffer = <void*>subtitle.ptr.data[index]

    # New-style buffer support.
    def __getbuffer__(self, Py_buffer *view, int flags):
        PyBuffer_FillInfo(view, self, self._buffer, self.buffer_size, 0, flags)


cdef class AssSubtitle(Subtitle):
    """
    Represents an ASS/Text subtitle format, as opposed to a bitmap Subtitle format.
    """
    def __repr__(self):
        return (
            f"<{self.__class__.__module__}.{self.__class__.__name__} "
            f"{self.text!r} at 0x{id(self):x}>"
        )

    @property
    def ass(self):
        """
        Returns the subtitle in the ASS/SSA format. Used by the vast majority of subtitle formats.
        """
        if self.ptr.ass is not NULL:
            return PyBytes_FromString(self.ptr.ass)
        return b""

    @property
    def dialogue(self):
        """
        Extract the dialogue from the ass format. Strip comments.
        """
        comma_count = 0
        i = 0
        cdef bytes ass_text = self.ass
        cdef bytes result = b""

        while comma_count < 8 and i < len(ass_text):
            if bytes([ass_text[i]]) == b",":
                comma_count += 1
            i += 1

        state = False
        while i < len(ass_text):
            char = bytes([ass_text[i]])
            next_char = b"" if i + 1 >= len(ass_text) else bytes([ass_text[i + 1]])

            if char == b"\\" and next_char == b"N":
                result += b"\n"
                i += 2
                continue

            if not state:
                if char == b"{" and next_char != b"\\":
                    state = True
                else:
                    result += char
            elif char == b"}":
                state = False
            i += 1

        return result

    @property
    def text(self):
        """
        Rarely used attribute. You're probably looking for dialogue.
        """
        if self.ptr.text is not NULL:
            return PyBytes_FromString(self.ptr.text)
        return b""
