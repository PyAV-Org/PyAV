cimport libav as lib

from av.audio.fifo cimport AudioFifo
from av.audio.format cimport AudioFormat
from av.audio.frame cimport AudioFrame
from av.audio.layout cimport AudioLayout
from av.audio.resampler cimport AudioResampler
from av.stream cimport Stream


cdef class AudioStream(Stream):

    cdef readonly AudioLayout layout
    cdef readonly AudioFormat format

    # For encoding.
    cdef AudioResampler resampler
