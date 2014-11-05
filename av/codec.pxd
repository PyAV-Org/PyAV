from libc.stdint cimport uint64_t

cimport libav as lib


cdef class Codec(object):
    
    cdef lib.AVCodec *eptr
    cdef lib.AVCodec *dptr
    cdef lib.AVCodecDescriptor *desc
    
    cdef lib.AVCodec* ptr(self)
    cdef uint64_t capabilities(self)



cdef class CodecContext(object):

    cdef lib.AVCodecContext *ptr
    cdef readonly Codec
