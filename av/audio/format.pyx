from cpython cimport Py_INCREF, PyTuple_New, PyTuple_SET_ITEM


cdef object _cinit_bypass_sentinel = object()

cdef AudioFormat blank_audio_format():
    """Make sure to call AudioFormat._init manually!"""
    return AudioFormat.__new__(AudioFormat, _cinit_bypass_sentinel)


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




