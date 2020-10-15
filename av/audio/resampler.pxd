from libc.stdint cimport uint64_t
cimport libav as lib

from av.audio.format cimport AudioFormat
from av.audio.frame cimport AudioFrame
from av.audio.layout cimport AudioLayout


cdef class AudioResampler(object):

    cdef readonly bint is_passthrough

    cdef lib.SwrContext *ptr

    cdef AudioFrame template

    # Source descriptors; not for public consumption.
    cdef unsigned int template_rate

    # Destination descriptors
    cdef readonly AudioFormat format
    cdef readonly AudioLayout layout
    cdef readonly int rate

    # Retiming.
    cdef readonly uint64_t samples_in
    cdef readonly double pts_per_sample_in
    cdef readonly uint64_t samples_out
    cdef readonly bint simple_pts_out

    cpdef resample(self, AudioFrame)
