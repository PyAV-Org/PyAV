from libc.stdint cimport uint8_t, uint16_t, uint32_t, uint64_t, int64_t


cdef extern from "libavcodec/avcodec.h":
    
    cdef enum AVCodecID:
        pass
    
    # See: http://ffmpeg.org/doxygen/trunk/structAVCodec.html
    cdef struct AVCodec:
        char *name
        char *long_name
    
    cdef enum AVPixelFormat:
        PIX_FMT_RGB24
        PIX_FMT_RGBA
            
    # See: http://ffmpeg.org/doxygen/trunk/structAVCodecContext.html
    cdef struct AVCodecContext:
        
        AVMediaType codec_type
        char codec_name[32]
        AVCodecID codec_id
        
        int width
        int height
        
        AVPixelFormat pix_fmt
        
        AVCodec *codec
        
    cdef AVCodec* avcodec_find_decoder(AVCodecID id)
    
    cdef int avcodec_open2(
        AVCodecContext *ctx,
        AVCodec *codec,
        AVDictionary **options,
    )
    cdef int avcodec_close(AVCodecContext *ctx)
    
    # See: http://ffmpeg.org/doxygen/trunk/structAVPicture.html
    cdef struct AVPicture:
        uint8_t **data
        int *linesize
    
    # See: http://ffmpeg.org/doxygen/trunk/structAVFrame.html
    # This is a strict superset of AVPicture.
    cdef struct AVFrame:
        uint8_t **data
        int *linesize
        uint8_t **extended_data
        int width
        int height
        int nb_samples # Audio samples
        int format
        int key_frame # 0 or 1.
        
        uint64_t pts
        
        uint8_t **base

    cdef AVFrame* avcodec_alloc_frame()
    
    cdef int avpicture_get_size(
        AVPixelFormat format,
        int width,
        int height,
    )
    
    cdef int avpicture_fill(
        AVPicture *picture,
        uint8_t *buffer,
        AVPixelFormat format,
        int width,
        int height
    )
    
    cdef struct AVPacket:
        
        uint64_t pts
        uint64_t dts
        
        int size
        int stream_index
        int flags
        
        int duration
    
    cdef int avcodec_decode_video2(
        AVCodecContext *ctx,
        AVFrame *picture,
        int *got_picture,
        AVPacket *packet,
    )
    
    cdef void av_free_packet(AVPacket*)
    
    cdef enum AVSubtitleType:
        SUBTITLE_NONE
        SUBTITLE_BITMAP
        SUBTITLE_TEXT
        SUBTITLE_ASS
    
    cdef struct AVSubtitleRect:
        int x
        int y
        int w
        int h
        int nb_colors
        AVPicture pict
        AVSubtitleType type
        char *text
        char *ass
        int flags
    
    cdef struct AVSubtitle:
        uint16_t format
        uint32_t start_display_time
        uint32_t end_display_time
        unsigned int num_rects
        AVSubtitleRect **rects
        int64_t pts
    
    cdef int avcodec_decode_subtitle2(
        AVCodecContext *ctx,
        AVSubtitle *sub,
        int *done,
        AVPacket *pkt,
    )
    
    cdef void avsubtitle_free(AVSubtitle*)

    
    