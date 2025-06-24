import cython
from cython.cimports.av.audio.format import get_audio_format
from cython.cimports.av.audio.layout import get_audio_layout
from cython.cimports.av.audio.plane import AudioPlane
from cython.cimports.av.error import err_check
from cython.cimports.av.utils import check_ndarray

_cinit_bypass_sentinel = object()


@cython.cfunc
def alloc_audio_frame() -> AudioFrame:
    return AudioFrame(_cinit_bypass_sentinel)


format_dtypes = {
    "dbl": "f8",
    "dblp": "f8",
    "flt": "f4",
    "fltp": "f4",
    "s16": "i2",
    "s16p": "i2",
    "s32": "i4",
    "s32p": "i4",
    "u8": "u1",
    "u8p": "u1",
}


@cython.cclass
class AudioFrame(Frame):
    """A frame of audio."""

    def __cinit__(self, format="s16", layout="stereo", samples=0, align=1):
        if format is _cinit_bypass_sentinel:
            return

        cy_format: AudioFormat = AudioFormat(format)
        cy_layout: AudioLayout = AudioLayout(layout)
        self._init(cy_format.sample_fmt, cy_layout.layout, samples, align)

    @cython.cfunc
    def _init(
        self,
        format: lib.AVSampleFormat,
        layout: lib.AVChannelLayout,
        nb_samples: cython.uint,
        align: cython.uint,
    ):
        self.ptr.nb_samples = nb_samples
        self.ptr.format = format
        self.ptr.ch_layout = layout

        # Sometimes this is called twice. Oh well.
        self._init_user_attributes()

        if self.layout.nb_channels != 0 and nb_samples:
            # Cleanup the old buffer.
            lib.av_freep(cython.address(self._buffer))

            # Get a new one.
            self._buffer_size = err_check(
                lib.av_samples_get_buffer_size(
                    cython.NULL, self.layout.nb_channels, nb_samples, format, align
                )
            )
            self._buffer = cython.cast(
                cython.pointer[uint8_t], lib.av_malloc(self._buffer_size)
            )
            if not self._buffer:
                raise MemoryError("cannot allocate AudioFrame buffer")

            # Connect the data pointers to the buffer.
            err_check(
                lib.avcodec_fill_audio_frame(
                    self.ptr,
                    self.layout.nb_channels,
                    cython.cast(lib.AVSampleFormat, self.ptr.format),
                    self._buffer,
                    self._buffer_size,
                    align,
                )
            )

    def __dealloc__(self):
        lib.av_freep(cython.address(self._buffer))

    @cython.cfunc
    def _init_user_attributes(self):
        self.layout = get_audio_layout(self.ptr.ch_layout)
        self.format = get_audio_format(cython.cast(lib.AVSampleFormat, self.ptr.format))

    def __repr__(self):
        return (
            f"<av.{self.__class__.__name__} pts={self.pts}, {self.samples} "
            f"samples at {self.rate}Hz, {self.layout.name}, {self.format.name} at 0x{id(self):x}>"
        )

    @staticmethod
    def from_ndarray(array, format="s16", layout="stereo"):
        """
        Construct a frame from a numpy array.
        """
        import numpy as np

        py_format = format if isinstance(format, AudioFormat) else AudioFormat(format)
        py_layout = layout if isinstance(layout, AudioLayout) else AudioLayout(layout)
        format = py_format.name

        # map avcodec type to numpy type
        try:
            dtype = np.dtype(format_dtypes[format])
        except KeyError:
            raise ValueError(
                f"Conversion from numpy array with format `{format}` is not yet supported"
            )

        # check input format
        nb_channels = py_layout.nb_channels
        check_ndarray(array, dtype, 2)
        if py_format.is_planar:
            if array.shape[0] != nb_channels:
                raise ValueError(
                    f"Expected planar `array.shape[0]` to equal `{nb_channels}` but got `{array.shape[0]}`"
                )
            samples = array.shape[1]
        else:
            if array.shape[0] != 1:
                raise ValueError(
                    f"Expected packed `array.shape[0]` to equal `1` but got `{array.shape[0]}`"
                )
            samples = array.shape[1] // nb_channels

        frame = AudioFrame(format=py_format, layout=py_layout, samples=samples)
        for i, plane in enumerate(frame.planes):
            plane.update(array[i, :])
        return frame

    @property
    def planes(self):
        """
        A tuple of :class:`~av.audio.plane.AudioPlane`.

        :type: tuple
        """
        plane_count: cython.int = 0
        while self.ptr.extended_data[plane_count]:
            plane_count += 1

        return tuple([AudioPlane(self, i) for i in range(plane_count)])

    @property
    def samples(self):
        """
        Number of audio samples (per channel).

        :type: int
        """
        return self.ptr.nb_samples

    @property
    def sample_rate(self):
        """
        Sample rate of the audio data, in samples per second.

        :type: int
        """
        return self.ptr.sample_rate

    @sample_rate.setter
    def sample_rate(self, value):
        self.ptr.sample_rate = value

    @property
    def rate(self):
        """Another name for :attr:`sample_rate`."""
        return self.ptr.sample_rate

    @rate.setter
    def rate(self, value):
        self.ptr.sample_rate = value

    def to_ndarray(self):
        """Get a numpy array of this frame.

        .. note:: Numpy must be installed.

        """
        import numpy as np

        try:
            dtype = np.dtype(format_dtypes[self.format.name])
        except KeyError:
            raise ValueError(
                f"Conversion from {self.format.name!r} format to numpy array is not supported."
            )

        if self.format.is_planar:
            count = self.samples
        else:
            count = self.samples * self.layout.nb_channels

        return np.vstack(
            [np.frombuffer(x, dtype=dtype, count=count) for x in self.planes]
        )
