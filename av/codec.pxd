cimport libav as lib

cimport av.format


cdef class Codec(object):
    
    cdef av.format.ContextProxy format_ctx
    cdef lib.AVCodecContext *ctx
    cdef lib.AVCodec *ptr
    

cdef class Packet(object):

    cdef readonly av.format.Stream stream
    cdef lib.AVPacket struct
    
    cpdef decode(self)


cdef class SubtitleProxy(object):

    cdef lib.AVSubtitle struct


cdef class Subtitle(object):
    
    cdef readonly av.format.Stream stream
    cdef SubtitleProxy proxy
    cdef readonly tuple rects


cdef class SubtitleRect(object):

    cdef SubtitleProxy proxy
    cdef lib.AVSubtitleRect *ptr
    cdef readonly bytes type
    