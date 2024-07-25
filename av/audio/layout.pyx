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

        if type(layout) is str:
            ret = lib.av_channel_layout_from_string(&c_layout, layout)
            if ret != 0:
                raise ValueError(f"Invalid layout: {layout}")
        elif isinstance(layout, AudioLayout):
            c_layout = (<AudioLayout>layout).layout
        else:
            raise TypeError("layout must be of type: string | av.AudioLayout")

        self._init(c_layout)

    cdef _init(self, lib.AVChannelLayout layout):
        self.layout = layout

    def __repr__(self):
        return f"<av.{self.__class__.__name__} {self.name!r}>"

    @property
    def nb_channels(self):
        return self.layout.nb_channels

    @property
    def name(self):
        """The canonical name of the audio layout."""
        cdef char layout_name[128]  # Adjust buffer size as needed
        cdef int ret

        ret = lib.av_channel_layout_describe(&self.layout, layout_name, sizeof(layout_name))
        if ret < 0:
            raise RuntimeError(f"Failed to get layout name: {ret}")

        return layout_name
