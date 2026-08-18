from av.audio.format cimport AudioFormat
from av.audio.frame cimport AudioFrame
from av.audio.layout cimport AudioLayout
from av.filter.graph cimport Graph


cdef class AudioResampler:
    cdef AudioFrame template
    cdef Graph graph
    cdef readonly AudioFormat format
    cdef readonly AudioLayout layout
    cdef readonly dict options
    cdef readonly int rate
    cdef readonly unsigned int frame_size
    cdef readonly bint is_passthrough

    cpdef list[AudioFrame] resample(self, AudioFrame)
