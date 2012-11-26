cimport libav as lib

from av.format cimport _AVFormatContextProxy


cdef class Codec(object):
    
    cdef _AVFormatContextProxy format_ctx
    cdef lib.AVCodecContext *ctx
    cdef lib.AVCodec *ptr
    

