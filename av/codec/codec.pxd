cimport libav as lib

from av.codec.hwaccel cimport HWConfig


cdef class Codec:

    cdef const lib.AVCodec *ptr
    cdef const lib.AVCodecDescriptor *desc
    cdef tuple[HWConfig, ...] _hardware_configs

    cdef void _init(self, name=?)


cdef Codec wrap_codec(const lib.AVCodec *ptr)
