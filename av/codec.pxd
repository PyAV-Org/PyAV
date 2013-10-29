from libc.stdint cimport uint8_t,uint64_t,int64_t

cimport libav as lib
from cpython cimport bool
cimport av.format


cdef class Codec(object):
    
    cdef av.format.ContextProxy format_ctx
    cdef lib.AVCodecContext *ctx
    cdef lib.AVCodec *ptr
    cdef lib.AVDictionary *options
    
    cdef lib.AVRational frame_rate_
    


