cimport libav as lib

from av.audio.frame cimport AudioFrame

cdef class AudioResampler(object):

    cdef lib.SwrContext *ptr

    cpdef resample(self, AudioFrame)
