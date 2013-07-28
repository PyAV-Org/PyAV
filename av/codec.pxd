from libc.stdint cimport uint8_t,int64_t
from cpython cimport bool

cimport libav as lib

cimport av.format

cdef struct PacketInfo:
    int64_t pts
    int64_t dts

cdef class Codec(object):
    
    cdef av.format.ContextProxy format_ctx
    cdef lib.AVCodecContext *ctx
    cdef lib.AVCodec *ptr
    cdef lib.AVDictionary *options
    cdef PacketInfo cur_pkt_info
    

cdef class Packet(object):

    cdef readonly av.format.Stream stream
    cdef readonly bool is_null
    cdef lib.AVPacket struct
   

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
    
    #pts and dts used for timing and frame count
    
    cdef readonly int64_t first_pkt_pts
    cdef readonly int64_t first_pkt_dts
    
    cdef readonly int64_t last_pkt_pts
    cdef readonly int64_t last_pkt_dts
    
    #set by seek module
    cdef readonly int frame_index

cdef class AudioFrame(object):
    
    cdef readonly Packet packet

    cdef lib.AVFrame *ptr

