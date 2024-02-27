from cpython cimport PyBuffer_FillInfo


cdef class SubtitleProxy:
    def __dealloc__(self):
        lib.avsubtitle_free(&self.struct)


cdef class SubtitleSet:
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

    if ptr.type == lib.SUBTITLE_NONE:
        return Subtitle(subtitle, index)
    elif ptr.type == lib.SUBTITLE_BITMAP:
        return BitmapSubtitle(subtitle, index)
    elif ptr.type == lib.SUBTITLE_TEXT:
        return TextSubtitle(subtitle, index)
    elif ptr.type == lib.SUBTITLE_ASS:
        return AssSubtitle(subtitle, index)
    else:
        raise ValueError("unknown subtitle type %r" % ptr.type)


cdef class Subtitle:
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


cdef class TextSubtitle(Subtitle):
    def __repr__(self):
        return (
            f"<{self.__class__.__module__}.{self.__class__.__name__} "
            f"{self.text!r} at 0x{id(self):x}>"
        )

    @property
    def text(self):
        return self.ptr.text


cdef class AssSubtitle(Subtitle):
    def __repr__(self):
        return (
            f"<{self.__class__.__module__}.{self.__class__.__name__} "
            f"{self.ass!r} at 0x{id(self):x}>"
        )

    @property
    def ass(self):
        return self.ptr.ass
