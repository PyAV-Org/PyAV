import sys


cdef str container_format_postfix = 'le' if sys.byteorder == 'little' else 'be'


cdef object _cinit_bypass_sentinel

cdef AudioFormat get_audio_format(lib.AVSampleFormat c_format):
    """Get an AudioFormat without going through a string."""
    cdef AudioFormat format = AudioFormat.__new__(AudioFormat, _cinit_bypass_sentinel)
    format._init(c_format)
    return format


cdef class AudioFormat(object):

    def __cinit__(self, name):

        if name is _cinit_bypass_sentinel:
            return

        cdef lib.AVSampleFormat sample_fmt = lib.av_get_sample_fmt(name)
        if sample_fmt < 0:
            raise ValueError('not a sample format: %r' % name)
        self._init(sample_fmt)

    cdef _init(self, lib.AVSampleFormat sample_fmt):
        self.sample_fmt = sample_fmt

    def __repr__(self):
        return '<av.AudioFormat %s>' % (self.name)

    property name:
        """Canonical name of the sample format."""
        def __get__(self):
            return lib.av_get_sample_fmt_name(self.sample_fmt)

    property bytes:
        def __get__(self):
            return lib.av_get_bytes_per_sample(self.sample_fmt)
    
    property bits:
        def __get__(self):
            return lib.av_get_bytes_per_sample(self.sample_fmt) << 3

    property is_planar:
        def __get__(self):
            return bool(lib.av_sample_fmt_is_planar(self.sample_fmt))

    property is_packed:
        def __get__(self):
            return not lib.av_sample_fmt_is_planar(self.sample_fmt)

    property planar:
        def __get__(self):
            if self.is_planar:
                return self
            return get_audio_format(lib.av_get_planar_sample_fmt(self.sample_fmt))

    property packed:
        def __get__(self):
            if self.is_packed:
                return self
            return get_audio_format(lib.av_get_packed_sample_fmt(self.sample_fmt))

    property container_name:
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





