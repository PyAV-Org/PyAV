cimport libav as lib


cdef object _cinit_bypass_sentinel

cdef AudioLayout get_audio_layout(int channels, uint64_t c_layout):
    """Get an AudioLayout from Cython land."""
    cdef AudioLayout layout = AudioLayout.__new__(AudioLayout, _cinit_bypass_sentinel)
    if channels and not c_layout:
        c_layout = default_layouts[channels]
    layout._init(c_layout)
    return layout


# TODO: What about av_get_default_channel_layout(...)?
cdef uint64_t default_layouts[17]
default_layouts[0] = 0
default_layouts[1] = lib.AV_CH_LAYOUT_MONO
default_layouts[2] = lib.AV_CH_LAYOUT_STEREO
default_layouts[3] = lib.AV_CH_LAYOUT_2POINT1
default_layouts[4] = lib.AV_CH_LAYOUT_4POINT0
default_layouts[5] = lib.AV_CH_LAYOUT_5POINT0_BACK
default_layouts[6] = lib.AV_CH_LAYOUT_5POINT1_BACK
default_layouts[7] = lib.AV_CH_LAYOUT_6POINT1
default_layouts[8] = lib.AV_CH_LAYOUT_7POINT1
default_layouts[9] = 0x01FF
default_layouts[10] = 0x03FF
default_layouts[11] = 0x07FF
default_layouts[12] = 0x0FFF
default_layouts[13] = 0x1FFF
default_layouts[14] = 0x3FFF
default_layouts[15] = 0x7FFF
default_layouts[16] = 0xFFFF


cdef dict channel_descriptions = {
    "FL": "front left",
    "FR": "front right",
    "FC": "front center",
    "LFE": "low frequency",
    "BL": "back left",
    "BR": "back right",
    "FLC": "front left-of-center",
    "FRC": "front right-of-center",
    "BC": "back center",
    "SL": "side left",
    "SR": "side right",
    "TC": "top center",
    "TFL": "top front left",
    "TFC": "top front center",
    "TFR": "top front right",
    "TBL": "top back left",
    "TBC": "top back center",
    "TBR": "top back right",
    "DL": "downmix left",
    "DR": "downmix right",
    "WL": "wide left",
    "WR": "wide right",
    "SDL": "surround direct left",
    "SDR": "surround direct right",
    "LFE2": "low frequency 2",
}


cdef class AudioLayout:
    def __init__(self, layout):
        if layout is _cinit_bypass_sentinel:
            return

        cdef uint64_t c_layout
        if isinstance(layout, int):
            if layout < 0 or layout > 8:
                raise ValueError(f"no layout with {layout} channels")

            c_layout = default_layouts[layout]
        elif isinstance(layout, str):
            c_layout = lib.av_get_channel_layout(layout)
        elif isinstance(layout, AudioLayout):
            c_layout = layout.layout
        else:
            raise TypeError("layout must be str or int")

        if not c_layout:
            raise ValueError(f"invalid channel layout: {layout}")

        self._init(c_layout)

    cdef _init(self, uint64_t layout):
        self.layout = layout
        self.nb_channels = lib.av_get_channel_layout_nb_channels(layout)  # This just counts bits.
        self.channels = tuple(AudioChannel(self, i) for i in range(self.nb_channels))

    def __repr__(self):
        return f"<av.{self.__class__.__name__} {self.name!r}>"

    @property
    def name(self):
        """The canonical name of the audio layout."""
        cdef char out[32]
        # Passing 0 as number of channels... fix this later?
        lib.av_get_channel_layout_string(out, 32, 0, self.layout)
        return <str>out


cdef class AudioChannel:
    def __cinit__(self, AudioLayout layout, int index):
        self.channel = lib.av_channel_layout_extract_channel(layout.layout, index)

    def __repr__(self):
        return f"<av.{self.__class__.__name__} {self.name!r} ({self.description})>"

    @property
    def name(self):
        """The canonical name of the audio channel."""
        return lib.av_get_channel_name(self.channel)

    @property
    def description(self):
        """A human description of the audio channel."""
        return channel_descriptions.get(self.name)
