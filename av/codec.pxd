cimport libav as lib

cimport av.format


cdef class Codec(object):
    
    cdef av.format.ContextProxy format_ctx
    cdef lib.AVCodecContext *ctx
    cdef lib.AVCodec *ptr
    

