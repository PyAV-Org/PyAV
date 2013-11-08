from cpython cimport Py_INCREF, PyTuple_New, PyTuple_SET_ITEM

cimport libav as lib


cdef object _cinit_bypass_sentinel = object()

cdef AudioLayout blank_audio_layout():
    """Make sure to call AudioLayout._init manually!"""
    return AudioLayout.__new__(AudioLayout, _cinit_bypass_sentinel)


cdef class AudioLayout(object):

    def __init__(self, layout):
        if layout is _cinit_bypass_sentinel:
            return

        cdef uint64_t c_layout
        if isinstance(layout, basestring):
            c_layout = lib.av_get_channel_layout(layout)
        elif isinstance(layout, int):
            c_layout = lib.av_get_default_channel_layout(layout)
        else:
            raise TypeError('layout must be str or int')

        if not c_layout:
            raise ValueError('invalid channel layout %r' % layout)

        self._init(c_layout)

    cdef _init(self, uint64_t layout):

        self.layout = layout
        self.nb_channels = lib.av_get_channel_layout_nb_channels(layout)
        self.channels = PyTuple_New(self.nb_channels)
        cdef AudioChannel c
        for i in range(self.nb_channels):
            # We are constructing this tuple manually, but since Cython does
            # not understand reference stealing we must manually Py_INCREF
            # so that when Cython Py_DECREFs it doesn't release our object.
            c = AudioChannel(self, i)
            Py_INCREF(c)
            PyTuple_SET_ITEM(self.channels, i, c)

    def __repr__(self):
        return '<av.audio.AudioLayout %r>' % self.name

    property name:
        """The canonical name of the audio layout."""
        def __get__(self):
            cdef bytes name = b'\0' * 32
            # Passing 0 as number of channels... fix this later?
            lib.av_get_channel_layout_string(name, 32, 0, self.layout)
            return name.strip('\0')


cdef class AudioChannel(object):

    def __cinit__(self, AudioLayout layout, int index):
        self.channel = lib.av_channel_layout_extract_channel(layout.layout, index)

    def __repr__(self):
        return '<av.audio.AudioChannel %r (%s)>' % (self.name, self.description)

    property name:
        """The canonical name of the audio channel."""
        def __get__(self):
            return lib.av_get_channel_name(self.channel)

    property description:
        """A description of the audio channel."""
        def __get__(self):
            return lib.av_get_channel_description(self.channel)


