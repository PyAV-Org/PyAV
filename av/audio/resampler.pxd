from libc.stdint cimport uint64_t
cimport libav as lib

from av.audio.format cimport AudioFormat
from av.audio.frame cimport AudioFrame
from av.audio.layout cimport AudioLayout
from av.filter.graph cimport Graph


cdef class AudioResampler(object):

    cdef readonly bint is_passthrough

    cdef lib.SwrContext *ptr

    cdef AudioFrame template

    # Destination descriptors
    cdef readonly AudioFormat format
    cdef readonly AudioLayout layout
    cdef readonly int rate
    cdef readonly unsigned int frame_size

    cdef Graph graph

    cpdef resample(self, AudioFrame)
