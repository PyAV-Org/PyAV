import sys


cdef str container_format_postfix = 'le' if sys.byteorder == 'little' else 'be'


cdef object _cinit_bypass_sentinel

cdef AudioFormat get_audio_format(lib.AVSampleFormat c_format):
    """Get an AudioFormat without going through a string."""
    cdef AudioFormat format = AudioFormat.__new__(AudioFormat, _cinit_bypass_sentinel)
    format._init(c_format)
    return format


cdef class AudioFormat(object):

    """Descriptor of audio formats."""

    def __cinit__(self, name):

        if name is _cinit_bypass_sentinel:
            return

        cdef lib.AVSampleFormat sample_fmt
        if isinstance(name, AudioFormat):
            sample_fmt = (<AudioFormat>name).sample_fmt
        else:
            sample_fmt = lib.av_get_sample_fmt(name)

        if sample_fmt < 0:
            raise ValueError('Not a sample format: %r' % name)

        self._init(sample_fmt)

    cdef _init(self, lib.AVSampleFormat sample_fmt):
        self.sample_fmt = sample_fmt

    def __repr__(self):
        return '<av.AudioFormat %s>' % (self.name)

    property name:
        """Canonical name of the sample format.

        >>> SampleFormat('s16p').name
        's16p'

        """
        def __get__(self):
            return <str>lib.av_get_sample_fmt_name(self.sample_fmt)

    property bytes:
        """Number of bytes per sample.

        >>> SampleFormat('s16p').bytes
        2

        """
        def __get__(self):
            return lib.av_get_bytes_per_sample(self.sample_fmt)

    property bits:
        """Number of bits per sample.

        >>> SampleFormat('s16p').bits
        16

        """
        def __get__(self):
            return lib.av_get_bytes_per_sample(self.sample_fmt) << 3

    property is_planar:
        """Is this a planar format?

        Strictly opposite of :attr:`is_packed`.

        """
        def __get__(self):
            return bool(lib.av_sample_fmt_is_planar(self.sample_fmt))

    property is_packed:
        """Is this a planar format?

        Strictly opposite of :attr:`is_planar`.

        """
        def __get__(self):
            return not lib.av_sample_fmt_is_planar(self.sample_fmt)

    property planar:
        """The planar variant of this format.

        Is itself when planar:

        >>> fmt = Format('s16p')
        >>> fmt.planar is fmt
        True

        """
        def __get__(self):
            if self.is_planar:
                return self
            return get_audio_format(lib.av_get_planar_sample_fmt(self.sample_fmt))

    property packed:
        """The packed variant of this format.

        Is itself when packed:

        >>> fmt = Format('s16')
        >>> fmt.packed is fmt
        True

        """
        def __get__(self):
            if self.is_packed:
                return self
            return get_audio_format(lib.av_get_packed_sample_fmt(self.sample_fmt))

    property container_name:
        """The name of a :class:`ContainerFormat` which directly accepts this data.

        :raises ValueError: when planar, since there are no such containers.

        """
        def __get__(self):

            if self.is_planar:
                raise ValueError('no planar container formats')

            if self.sample_fmt == lib.AV_SAMPLE_FMT_U8:
                return 'u8'
            elif self.sample_fmt == lib.AV_SAMPLE_FMT_S16:
                return 's16' + container_format_postfix
            elif self.sample_fmt == lib.AV_SAMPLE_FMT_S32:
                return 's32' + container_format_postfix
            elif self.sample_fmt == lib.AV_SAMPLE_FMT_FLT:
                return 'f32' + container_format_postfix
            elif self.sample_fmt == lib.AV_SAMPLE_FMT_DBL:
                return 'f64' + container_format_postfix

            raise ValueError('unknown layout')
