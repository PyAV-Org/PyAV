from libc.stdint cimport uint8_t, uint16_t, uint32_t, uint64_t, int64_t

cdef extern from "libavcodec_compat.h":
    pass

cdef extern from "libavcodec/avcodec.h":

    cdef void avcodec_register_all()
    
    cdef int64_t AV_NOPTS_VALUE
    cdef int CODEC_FLAG_GLOBAL_HEADER
    cdef int CODEC_CAP_VARIABLE_FRAME_SIZE
    
    cdef int AV_PKT_FLAG_KEY
    
    cdef int FF_COMPLIANCE_VERY_STRICT
    cdef int FF_COMPLIANCE_STRICT
    cdef int FF_COMPLIANCE_NORMAL
    cdef int FF_COMPLIANCE_UNOFFICIAL
    cdef int FF_COMPLIANCE_EXPERIMENTAL

    cdef enum AVCodecID:
        AV_CODEC_ID_NONE
        AV_CODEC_ID_MPEG2VIDEO
        AV_CODEC_ID_MPEG1VIDEO
    
    # See: http://ffmpeg.org/doxygen/trunk/structAVCodec.html
    cdef struct AVCodec:
        char *name
        char *long_name
        AVMediaType type
        AVCodecID id
        int capabilities
        
        AVSampleFormat* sample_fmts
        
            
    # See: http://ffmpeg.org/doxygen/trunk/structAVCodecContext.html
    cdef struct AVCodecContext:
        
        AVMediaType codec_type
        char codec_name[32]
        AVCodecID codec_id
        int flags
        
        AVFrame* coded_frame
        
        int width
        int height
        int bit_rate
        int bit_rate_tolerance
        int gop_size #the number of pictures in a group of pictures, or 0 for intra_only 
        int max_b_frames
        int mb_decision
        
        int global_quality
        int compression_level
        
        int qmin
        int qmax
        int rc_max_rate
        int rc_min_rate
        int rc_buffer_size
        float rc_max_available_vbv_use
        float rc_min_vbv_overflow_use
        
        AVRational time_base
        AVPixelFormat pix_fmt
        
        AVCodec *codec

        # Video.
        AVRational sample_aspect_ratio

        # Audio.
        AVSampleFormat sample_fmt
        int sample_rate
        int channels
        int frame_size
        int channel_layout
        
    cdef struct AVCodecDescriptor:
        AVCodecID id
        AVMediaType type
        char *name
        char *long_name
        int props
        
    cdef AVCodec* avcodec_find_decoder(AVCodecID id)
    cdef AVCodec* avcodec_find_encoder(AVCodecID id)
    
    cdef AVCodec* avcodec_find_decoder_by_name(char *name)
    cdef AVCodec* avcodec_find_encoder_by_name(char *name)
    
    cdef AVCodecDescriptor* avcodec_descriptor_get (AVCodecID id)
    cdef AVCodecDescriptor* avcodec_descriptor_get_by_name (char *name)
    
    cdef char* avcodec_get_name(AVCodecID id)
    
    cdef int avcodec_open2(
        AVCodecContext *ctx,
        AVCodec *codec,
        AVDictionary **options,
    )
    
    cdef int avcodec_is_open(AVCodecContext *ctx )
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
        #int channels # Audio channels
        int sample_rate #Audio Sample rate 
        int channel_layout # Audio channel_layout
        int format
        int key_frame # 0 or 1.
        
        int64_t pts
        int64_t pkt_pts
        
        int pkt_size
        
        uint8_t **base

    cdef AVFrame* avcodec_alloc_frame()
    
    cdef int avpicture_alloc(
        AVPicture *picture, 
        AVPixelFormat pix_fmt, 
        int width, 
        int height
    )
    
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
        
        int64_t pts
        int64_t dts
        uint8_t *data
        
        int size
        int stream_index
        int flags
        
        int duration
    
    cdef int avcodec_decode_video2(
        AVCodecContext *ctx,
        AVFrame *frame,
        int *got_frame,
        AVPacket *packet,
    )

    cdef int avcodec_decode_audio4(
        AVCodecContext *ctx,
        AVFrame *frame,
        int *got_frame,
        AVPacket *packet,
    )
    
    cdef int avcodec_encode_audio2(
        AVCodecContext *ctx,
        AVPacket *avpkt,
        AVFrame *frame,
        int *got_packet_ptr
    )
     
    cdef int avcodec_encode_video2(
        AVCodecContext *ctx,
        AVPacket *avpkt,
        AVFrame *frame,
        int *got_packet_ptr
    )
    
    cdef int avcodec_fill_audio_frame(
        AVFrame *frame,
        int nb_channels,
        AVSampleFormat sample_fmt,
        uint8_t *buf,
        int buf_size,
        int align
    )
    
    cdef void avcodec_free_frame(AVFrame **frame)
    
    cdef void av_free_packet(AVPacket*)
    cdef void av_init_packet(AVPacket*)
    
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

    cdef int avcodec_encode_subtitle(
        AVCodecContext *avctx,
        uint8_t *buf,
        int buf_size,
        AVSubtitle *sub
    )
    
    cdef void avsubtitle_free(AVSubtitle*)
    
    cdef void avcodec_get_frame_defaults(AVFrame* frame)
    
    cdef int avcodec_get_context_defaults3(
        AVCodecContext *ctx, 
        AVCodec *codec
     )
    
    cdef int64_t av_frame_get_best_effort_timestamp(AVFrame *frame)
    cdef void avcodec_flush_buffers(AVCodecContext *ctx)
    
    
