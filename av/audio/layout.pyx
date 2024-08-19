cimport libav as lib
from cpython.bytes cimport PyBytes_FromStringAndSize

from dataclasses import dataclass


@dataclass
class AudioChannel:
    name: str
    description: str

    def __repr__(self):
        return f"<av.AudioChannel '{self.name}' ({self.description})>"

cdef object _cinit_bypass_sentinel

cdef AudioLayout get_audio_layout(lib.AVChannelLayout c_layout):
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
            raise TypeError(f"layout must be of type: string | av.AudioLayout, got {type(layout)}")

        self._init(c_layout)

    cdef _init(self, lib.AVChannelLayout layout):
        self.layout = layout

    def __repr__(self):
        return f"<av.{self.__class__.__name__} {self.name!r}>"

    def __eq__(self, other):
        return isinstance(other, AudioLayout) and self.name == other.name and self.nb_channels == other.nb_channels

    @property
    def nb_channels(self):
        return self.layout.nb_channels

    @property
    def channels(self):
        cdef lib.AVChannel channel
        cdef char buf[16]
        cdef char buf2[128]

        results = []

        for index in range(self.layout.nb_channels):
            channel = lib.av_channel_layout_channel_from_index(&self.layout, index);
            size = lib.av_channel_name(buf, sizeof(buf), channel) - 1
            size2 = lib.av_channel_description(buf2, sizeof(buf2), channel) - 1
            results.append(
                AudioChannel(
                    PyBytes_FromStringAndSize(buf, size).decode("utf-8"),
                    PyBytes_FromStringAndSize(buf2, size2).decode("utf-8"),
                )
            )

        return tuple(results)

    @property
    def name(self) -> str:
        """The canonical name of the audio layout."""
        cdef char layout_name[128]
        cdef int ret

        ret = lib.av_channel_layout_describe(&self.layout, layout_name, sizeof(layout_name))
        if ret < 0:
            raise RuntimeError(f"Failed to get layout name: {ret}")

        return layout_name