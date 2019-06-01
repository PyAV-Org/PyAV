from cpython cimport PyBuffer_FillInfo


cdef class SubtitleProxy(object):
    def __dealloc__(self):
        lib.avsubtitle_free(&self.struct)


cdef class SubtitleSet(object):

    def __cinit__(self, SubtitleProxy proxy):
        self.proxy = proxy
        cdef int i
        self.rects = tuple(build_subtitle(self, i) for i in range(self.proxy.struct.num_rects))

    def __repr__(self):
        return '<%s.%s at 0x%x>' % (
            self.__class__.__module__,
            self.__class__.__name__,
            id(self),
        )

    property format:
        def __get__(self): return self.proxy.struct.format
    property start_display_time:
        def __get__(self): return self.proxy.struct.start_display_time
    property end_display_time:
        def __get__(self): return self.proxy.struct.end_display_time
    property pts:
        def __get__(self): return self.proxy.struct.pts

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
        raise ValueError('subtitle rect index out of range')
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
        raise ValueError('unknown subtitle type %r' % ptr.type)


cdef class Subtitle(object):

    def __cinit__(self, SubtitleSet subtitle, int index):
        if index < 0 or <unsigned int>index >= subtitle.proxy.struct.num_rects:
            raise ValueError('subtitle rect index out of range')
        self.proxy = subtitle.proxy
        self.ptr = self.proxy.struct.rects[index]

        if self.ptr.type == lib.SUBTITLE_NONE:
            self.type = b'none'
        elif self.ptr.type == lib.SUBTITLE_BITMAP:
            self.type = b'bitmap'
        elif self.ptr.type == lib.SUBTITLE_TEXT:
            self.type = b'text'
        elif self.ptr.type == lib.SUBTITLE_ASS:
            self.type = b'ass'
        else:
            raise ValueError('unknown subtitle type %r' % self.ptr.type)

    def __repr__(self):
        return '<%s.%s at 0x%x>' % (
            self.__class__.__module__,
            self.__class__.__name__,
            id(self),
        )


cdef class BitmapSubtitle(Subtitle):

    def __cinit__(self, SubtitleSet subtitle, int index):
        self.planes = tuple(
            BitmapSubtitlePlane(self, i)
            for i in range(4)
            if self.ptr.linesize[i]
        )

    def __repr__(self):
        return '<%s.%s %dx%d at %d,%d; at 0x%x>' % (
            self.__class__.__module__,
            self.__class__.__name__,
            self.width,
            self.height,
            self.x,
            self.y,
            id(self),
        )

    property x:
        def __get__(self): return self.ptr.x
    property y:
        def __get__(self): return self.ptr.y
    property width:
        def __get__(self): return self.ptr.w
    property height:
        def __get__(self): return self.ptr.h
    property nb_colors:
        def __get__(self): return self.ptr.nb_colors

    def __len__(self):
        return len(self.planes)

    def __iter__(self):
        return iter(self.planes)

    def __getitem__(self, i):
        return self.planes[i]


cdef class BitmapSubtitlePlane(object):

    def __cinit__(self, BitmapSubtitle subtitle, int index):

        if index >= 4:
            raise ValueError('BitmapSubtitles have only 4 planes')
        if not subtitle.ptr.linesize[index]:
            raise ValueError('plane does not exist')

        self.subtitle = subtitle
        self.index = index
        self.buffer_size = subtitle.ptr.w * subtitle.ptr.h
        self._buffer = <void*>subtitle.ptr.data[index]

    # PyBuffer_FromMemory(self.ptr.data[i], self.width * self.height)

    # Legacy buffer support. For `buffer` and PIL.
    # See: http://docs.python.org/2/c-api/typeobj.html#PyBufferProcs

    def __getsegcount__(self, Py_ssize_t *len_out):
        if len_out != NULL:
            len_out[0] = <Py_ssize_t>self.buffer_size
        return 1

    def __getreadbuffer__(self, Py_ssize_t index, void **data):
        if index:
            raise RuntimeError("accessing non-existent buffer segment")
        data[0] = self._buffer
        return <Py_ssize_t>self.buffer_size

    def __getwritebuffer__(self, Py_ssize_t index, void **data):
        if index:
            raise RuntimeError("accessing non-existent buffer segment")
        data[0] = self._buffer
        return <Py_ssize_t>self.buffer_size

    # New-style buffer support.

    def __getbuffer__(self, Py_buffer *view, int flags):
        PyBuffer_FillInfo(view, self, self._buffer, self.buffer_size, 0, flags)


cdef class TextSubtitle(Subtitle):

    def __repr__(self):
        return '<%s.%s %r at 0x%x>' % (
            self.__class__.__module__,
            self.__class__.__name__,
            self.text,
            id(self),
        )

    property text:
        def __get__(self): return self.ptr.text


cdef class AssSubtitle(Subtitle):

    def __repr__(self):
        return '<%s.%s %r at 0x%x>' % (
            self.__class__.__module__,
            self.__class__.__name__,
            self.ass,
            id(self),
        )

    property ass:
        def __get__(self): return self.ptr.ass
