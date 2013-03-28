from libc.stdint cimport uint8_t

cimport libav as lib

cimport av.format


cdef class Codec(object):
    
    cdef av.format.ContextProxy format_ctx
    cdef lib.AVCodecContext *ctx
    cdef lib.AVCodec *ptr
    cdef lib.AVDictionary *options
    

cdef class Packet(object):

    cdef readonly av.format.Stream stream
    cdef lib.AVPacket struct
    
    cpdef decode(self)


cdef class SubtitleProxy(object):

    cdef lib.AVSubtitle struct


cdef class Subtitle(object):
    
    cdef readonly Packet packet
    cdef SubtitleProxy proxy
    cdef readonly tuple rects


cdef class SubtitleRect(object):

    cdef SubtitleProxy proxy
    cdef lib.AVSubtitleRect *ptr
    cdef readonly bytes type


cdef class VideoFrame(object):
    
    cdef readonly Packet packet
    
    cdef lib.AVFrame *raw_ptr
    cdef lib.AVFrame *rgb_ptr
    cdef uint8_t *buffer_


cdef class AudioFrame(object):
    
    cdef readonly Packet packet

