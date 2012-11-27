cimport libav as lib

cimport av.format


cdef class Codec(object):
    
    cdef av.format.ContextProxy format_ctx
    cdef lib.AVCodecContext *ctx
    cdef lib.AVCodec *ptr
    

cdef class Packet(object):

    cdef readonly av.format.Stream stream
    cdef lib.AVPacket packet
    