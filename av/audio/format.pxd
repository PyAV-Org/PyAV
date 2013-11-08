cimport libav as lib


cdef class AudioFormat(object):

    cdef lib.AVSampleFormat sample_fmt
    
    cdef _init(self, lib.AVSampleFormat sample_fmt)


cdef AudioFormat blank_audio_format()
