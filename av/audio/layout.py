from dataclasses import dataclass

import cython
from cython.cimports import libav as lib
from cython.cimports.cpython.bytes import PyBytes_FromStringAndSize


@dataclass
class AudioChannel:
    name: str
    description: str

    def __repr__(self):
        return f"<av.AudioChannel '{self.name}' ({self.description})>"


_cinit_bypass_sentinel = cython.declare(object, object())


@cython.cfunc
def get_audio_layout(c_layout: lib.AVChannelLayout) -> AudioLayout:
    """Get an AudioLayout from Cython land."""
    layout: AudioLayout = AudioLayout(_cinit_bypass_sentinel)
    layout.layout = c_layout
    return layout


@cython.cclass
class AudioLayout:
    def __cinit__(self, layout):
        if layout is _cinit_bypass_sentinel:
            return

        if type(layout) is str:
            ret = lib.av_channel_layout_from_string(cython.address(c_layout), layout)
            if ret != 0:
                raise ValueError(f"Invalid layout: {layout}")
        elif isinstance(layout, AudioLayout):
            c_layout = cython.cast(AudioLayout, layout).layout
        else:
            raise TypeError(
                f"layout must be of type: string | av.AudioLayout, got {type(layout)}"
            )

        self.layout = c_layout

    def __repr__(self):
        return f"<av.{self.__class__.__name__} {self.name!r}>"

    def __eq__(self, other):
        return (
            isinstance(other, AudioLayout)
            and self.name == other.name
            and self.nb_channels == other.nb_channels
        )

    @property
    def nb_channels(self):
        return self.layout.nb_channels

    @property
    def channels(self):
        buf: cython.char[16]
        buf2: cython.char[128]

        results: list = []
        for index in range(self.layout.nb_channels):
            size = lib.av_channel_name(
                buf,
                cython.sizeof(buf),
                lib.av_channel_layout_channel_from_index(
                    cython.address(self.layout), index
                ),
            )
            size2 = lib.av_channel_description(
                buf2,
                cython.sizeof(buf2),
                lib.av_channel_layout_channel_from_index(
                    cython.address(self.layout), index
                ),
            )
            results.append(
                AudioChannel(
                    PyBytes_FromStringAndSize(buf, size - 1).decode("utf-8"),
                    PyBytes_FromStringAndSize(buf2, size2 - 1).decode("utf-8"),
                )
            )

        return tuple(results)

    @property
    def name(self) -> str:
        """The canonical name of the audio layout."""
        layout_name: cython.char[129]
        ret: cython.int = lib.av_channel_layout_describe(
            cython.address(self.layout), layout_name, cython.sizeof(layout_name)
        )
        if ret < 0:
            raise RuntimeError(f"Failed to get layout name: {ret}")

        return layout_name
