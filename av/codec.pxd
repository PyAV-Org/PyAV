cimport libav as lib


cdef class Codec(object):
    
    cdef lib.AVCodec *ptr


cdef class Encoder(Codec):
    pass


cdef class Decoder(Codec):
    pass


cdef class CodecContext(object):

    cdef lib.AVCodecContext *ptr
    cdef readonly Codec
