import logging

from av.audio.format cimport get_audio_format
from av.audio.layout cimport get_audio_layout
from av.audio.plane cimport AudioPlane
from av.error cimport err_check
from av.utils cimport check_ndarray, check_ndarray_shape


cdef object _cinit_bypass_sentinel


format_dtypes = {
    'dbl': 'float64',
    'dblp': 'float64',
    'flt': 'float32',
    'fltp': 'float32',
    's16': 'int16',
    's16p': 'int16',
    's32': 'int32',
    's32p': 'int32',
    'u8': 'uint8',
    'u8p': 'uint8',
}


cdef AudioFrame alloc_audio_frame():
    """Get a mostly uninitialized AudioFrame.

    You MUST call AudioFrame._init(...) or AudioFrame._init_user_attributes()
    before exposing to the user.

    """
    return AudioFrame.__new__(AudioFrame, _cinit_bypass_sentinel)


cdef class AudioFrame(Frame):

    """A frame of audio."""

    def __cinit__(self, format='s16', layout='stereo', samples=0, align=1):
        if format is _cinit_bypass_sentinel:
            return

        cdef AudioFormat cy_format = AudioFormat(format)
        cdef AudioLayout cy_layout = AudioLayout(layout)
        self._init(cy_format.sample_fmt, cy_layout.layout, samples, align)

    cdef _init(self, lib.AVSampleFormat format, uint64_t layout, unsigned int nb_samples, unsigned int align):

        self.ptr.nb_samples = nb_samples
        self.ptr.format = <int>format
        self.ptr.channel_layout = layout

        # Sometimes this is called twice. Oh well.
        self._init_user_attributes()

        # Audio filters need AVFrame.channels to match number of channels from layout.
        self.ptr.channels = self.layout.nb_channels

        cdef size_t buffer_size
        if self.layout.channels and nb_samples:

            # Cleanup the old buffer.
            lib.av_freep(&self._buffer)

            # Get a new one.
            self._buffer_size = err_check(lib.av_samples_get_buffer_size(
                NULL,
                len(self.layout.channels),
                nb_samples,
                format,
                align
            ))
            self._buffer = <uint8_t *>lib.av_malloc(self._buffer_size)
            if not self._buffer:
                raise MemoryError("cannot allocate AudioFrame buffer")

            # Connect the data pointers to the buffer.
            err_check(lib.avcodec_fill_audio_frame(
                self.ptr,
                len(self.layout.channels),
                <lib.AVSampleFormat>self.ptr.format,
                self._buffer,
                self._buffer_size,
                align
            ))

    def __dealloc__(self):
        lib.av_freep(&self._buffer)

    cdef _init_user_attributes(self):
        self.layout = get_audio_layout(0, self.ptr.channel_layout)
        self.format = get_audio_format(<lib.AVSampleFormat>self.ptr.format)

    def __repr__(self):
        return '<av.%s %d, pts=%s, %d samples at %dHz, %s, %s at 0x%x>' % (
            self.__class__.__name__,
            self.index,
            self.pts,
            self.samples,
            self.rate,
            self.layout.name,
            self.format.name,
            id(self),
        )

    @staticmethod
    def from_ndarray(array, format=None, layout=None):
        """
        Construct a frame from a numpy array.

        .. note:: The type and number of channels are automatically deduced.
        """
        import numpy as np

        if format is not None:
            logging.warning('deprecated warning : the `format` argument is ignored')

        # map numpy type to avcodec type
        format = {np_t: av_t for av_t, np_t in format_dtypes.items()}.get(array.dtype.name, None)
        if format is None:
            raise ValueError('The numpy array format `%s` is not yet supported' % array.dtype.name)
        if layout is None:
            if array.shape[0] == 1:
                layout = 'mono'
            elif array.shape[0] == 2:
                layout = 'stereo'
            else:
                raise ValueError('Only 1 or 2 channels are allowed, not %d.' % array.shape[0])
        else:
            logging.warning('deprecated warning : the `layout` argument can be deduced from the array shape.')

        # conversion of the shape into an acceptable type
        array = np.expand_dims(array.ravel(order='F'), 0)

        # check input format
        nb_channels = len(AudioLayout(layout).channels)
        check_ndarray(array, array.dtype, 2)
        if AudioFormat(format).is_planar:
            check_ndarray_shape(array, array.shape[0] == nb_channels)
            samples = array.shape[1]
        else:
            check_ndarray_shape(array, array.shape[0] == 1)
            samples = array.shape[1] // nb_channels

        frame = AudioFrame(format=format, layout=layout, samples=samples)
        for i, plane in enumerate(frame.planes):
            plane.update(array[i, :])
        return frame

    @property
    def planes(self):
        """
        A tuple of :class:`~av.audio.plane.AudioPlane`.

        :type: tuple
        """
        cdef int plane_count = 0
        while self.ptr.extended_data[plane_count]:
            plane_count += 1

        return tuple([AudioPlane(self, i) for i in range(plane_count)])

    property samples:
        """
        Number of audio samples (per channel).

        :type: int
        """
        def __get__(self):
            return self.ptr.nb_samples

    property sample_rate:
        """
        Sample rate of the audio data, in samples per second.

        :type: int
        """
        def __get__(self):
            return self.ptr.sample_rate

        def __set__(self, value):
            self.ptr.sample_rate = value

    property rate:
        """Another name for :attr:`sample_rate`."""
        def __get__(self):
            return self.ptr.sample_rate

        def __set__(self, value):
            self.ptr.sample_rate = value

    def to_ndarray(self, **kwargs):
        """Get a numpy array of this frame.

        .. note:: Numpy must be installed.

        """
        import numpy as np

        # map avcodec type to numpy type
        try:
            dtype = np.dtype(format_dtypes[self.format.name])
        except KeyError:
            raise ValueError("Conversion from {!r} format to numpy array is not supported.".format(self.format.name))

        if self.format.is_planar:
            count = self.samples
        else:
            count = self.samples * len(self.layout.channels)

        # convert and return data
        return np.vstack([np.frombuffer(x, dtype=dtype, count=count) for x in self.planes])
