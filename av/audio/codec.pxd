from av.codec cimport Codec
from av.audio.layout cimport AudioLayout
from av.audio.format cimport AudioFormat

cdef class AudioCodec(Codec):

    cdef readonly AudioLayout layout
    cdef readonly AudioFormat format
