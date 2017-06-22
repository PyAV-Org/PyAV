from libc.stdint cimport uint64_t

cimport libav as lib


cdef class Codec(object):

    cdef lib.AVCodec *ptr
    cdef lib.AVCodecDescriptor *desc
    cdef readonly bint is_encoder

    cdef _init(self, name=?)


cdef Codec wrap_codec(lib.AVCodec *ptr)
