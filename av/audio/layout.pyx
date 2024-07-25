cimport libav as lib


cdef object _cinit_bypass_sentinel

cdef AudioLayout get_audio_layout(int channels, lib.AVChannelLayout c_layout):
    """Get an AudioLayout from Cython land."""
    cdef AudioLayout layout = AudioLayout.__new__(AudioLayout, _cinit_bypass_sentinel)
    layout._init(c_layout)
    return layout



cdef class AudioLayout:
    def __init__(self, layout):
        if layout is _cinit_bypass_sentinel:
            return

        cdef lib.AVChannelLayout c_layout
        # if isinstance(layout, int):
        #     if layout < 0 or layout > 8:
        #         raise ValueError(f"no layout with {layout} channels")

        #     c_layout = default_layouts[layout]
        # elif isinstance(layout, str):
        #     c_layout = lib.av_get_channel_layout(layout)
        if isinstance(layout, AudioLayout):
            c_layout = (<AudioLayout>layout).layout
        else:
            raise TypeError("layout must be str or int")

        self._init(c_layout)

    cdef _init(self, lib.AVChannelLayout layout):
        self.layout = layout
        # TODO
        self.nb_channels = 2 # lib.av_get_channel_layout_nb_channels(layout)  # This just counts bits.
        # self.channels = tuple(AudioChannel(self, i) for i in range(self.nb_channels))

    def __repr__(self):
        return f"<av.{self.__class__.__name__} {self.name!r}>"

    @property
    def name(self):
        """The canonical name of the audio layout."""
        return "TODO"
        # cdef char out[32]
        # # Passing 0 as number of channels... fix this later?
        # lib.av_get_channel_layout_string(out, 32, 0, self.layout)
        # return <str>out



