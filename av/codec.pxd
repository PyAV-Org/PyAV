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
    cdef lib.AVRational time_base_

cdef class VideoFrame(Frame):

    cdef int buffer_size
    cdef uint8_t *buffer_
    cdef readonly int frame_index
    
    cdef SwsContextProxy sws_proxy
    cpdef reformat(self, int width, int height, char* pix_fmt)


cdef class AudioFrame(Frame):
    cdef int buffer_size
    cdef int align
    cdef uint8_t **buffer_
    cdef readonly int frame_index
    
    cdef alloc_frame(self, int channels, lib.AVSampleFormat sample_fmt, int nb_samples)
    cdef fill_frame(self, int nb_samples)
    cdef SwrContextProxy swr_proxy
    cpdef resample(self, bytes channel_layout, bytes sample_fmt, int sample_rate)
    
cdef class AudioFifo:
    cdef lib.AVAudioFifo *ptr
    
    cdef uint64_t channel_layout_
    cdef int channels_
    cdef bool add_silence
    
    cdef lib.AVSampleFormat sample_fmt_
    cdef int sample_rate_
    
    cdef int64_t last_pts
    cdef int64_t pts_offset
    cdef lib.AVRational time_base_
    
    cpdef write(self, AudioFrame frame)
    cpdef read(self, int nb_samples=*)
    

