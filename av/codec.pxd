from libc.stdint cimport uint8_t

cimport libav as lib
from cpython cimport bool
cimport av.format


cdef class Codec(object):
    
    cdef av.format.ContextProxy format_ctx
    cdef lib.AVCodecContext *ctx
    cdef lib.AVCodec *ptr
    cdef lib.AVDictionary *options
    

cdef class Packet(object):

    cdef readonly av.format.Stream stream
    cdef lib.AVPacket struct
    cdef readonly bool is_null

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
    
cdef class SwsContextProxy(object):

    cdef lib.SwsContext *ptr
    
cdef class SwrContextProxy(object):

    cdef lib.SwrContext *ptr

cdef class Frame(object):
    cdef lib.AVFrame *ptr

cdef class VideoFrame(Frame):

    cdef int buffer_size
    cdef uint8_t *buffer_
    cdef readonly int frame_index
    
    cdef SwsContextProxy sws_proxy
    cpdef reformat(self, int width, int height, char* pix_fmt)


cdef class AudioFrame(Frame):
    cdef int buffer_size
    cdef uint8_t **buffer_
    cdef readonly int frame_index
    
    cdef SwrContextProxy swr_proxy
    #cpdef resample(self, char* channel_layout, char* sample_fmt, int sample_rate)

