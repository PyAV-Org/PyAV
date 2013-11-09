from libc.stdint cimport uint8_t, uint64_t, int64_t

cimport libav as lib
from cpython cimport bool
from av.container cimport ContainerProxy
from av.stream cimport Stream


cdef class Codec(object):
    
    cdef ContainerProxy format_ctx
    cdef lib.AVCodecContext *ctx
    cdef lib.AVCodec *ptr
    cdef lib.AVDictionary *options
    
    cdef lib.AVRational frame_rate_
    

cdef Codec codec_factory(Stream stream)
