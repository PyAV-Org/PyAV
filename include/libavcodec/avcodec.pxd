from libc.stdint cimport uint8_t, uint16_t, uint32_t, uint64_t, int64_t


cdef extern from "libavcodec/avcodec.pyav.h" nogil:

    cdef int   avcodec_version()
    cdef char* avcodec_configuration()
    cdef char* avcodec_license()

    cdef void avcodec_register_all()
    
    cdef int64_t AV_NOPTS_VALUE
    cdef int CODEC_FLAG_GLOBAL_HEADER

    # AVCodecDescriptor.props
    cdef uint64_t AV_CODEC_PROP_INTRA_ONLY 
    cdef uint64_t AV_CODEC_PROP_LOSSY      
    cdef uint64_t AV_CODEC_PROP_LOSSLESS   
    cdef uint64_t AV_CODEC_PROP_REORDER    
    cdef uint64_t AV_CODEC_PROP_BITMAP_SUB  
    cdef uint64_t AV_CODEC_PROP_TEXT_SUB    

    #AVCodec.capabilities
    cdef uint64_t CODEC_CAP_DRAW_HORIZ_BAND
    cdef uint64_t CODEC_CAP_DR1
    cdef uint64_t CODEC_CAP_TRUNCATED
    cdef uint64_t CODEC_CAP_HWACCEL
    cdef uint64_t CODEC_CAP_DELAY
    cdef uint64_t CODEC_CAP_SMALL_LAST_FRAME
    cdef uint64_t CODEC_CAP_HWACCEL_VDPAU
    cdef uint64_t CODEC_CAP_SUBFRAMES
    cdef uint64_t CODEC_CAP_EXPERIMENTAL
    cdef uint64_t CODEC_CAP_CHANNEL_CONF
    cdef uint64_t CODEC_CAP_NEG_LINESIZES
    cdef uint64_t CODEC_CAP_FRAME_THREADS
    cdef uint64_t CODEC_CAP_SLICE_THREADS
    cdef uint64_t CODEC_CAP_PARAM_CHANGE
    cdef uint64_t CODEC_CAP_AUTO_THREADS
    cdef uint64_t CODEC_CAP_VARIABLE_FRAME_SIZE
    cdef uint64_t CODEC_CAP_INTRA_ONLY
    cdef uint64_t CODEC_CAP_LOSSLESS
    
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
        
        AVRational* supported_framerates
        AVSampleFormat* sample_fmts
        AVPixelFormat* pix_fmts
        int* supported_samplerates

        AVClass *priv_class
        
        
    cdef AVCodec* av_codec_next(AVCodec*)
    cdef int av_codec_is_encoder(AVCodec*)
    cdef int av_codec_is_decoder(AVCodec*)
        
    cdef struct AVCodecDescriptor:
        AVCodecID id
        char *name
        char *long_name
        int props
        char **mime_types

    AVCodecDescriptor* avcodec_descriptor_get(AVCodecID)   


    # See: http://ffmpeg.org/doxygen/trunk/structAVCodecContext.html
    cdef struct AVCodecContext:
        
        AVMediaType codec_type
        char codec_name[32]
        unsigned int codec_tag
        AVCodecID codec_id

        int flags
        int thread_count
        
        int profile

        AVFrame* coded_frame
        
        int bit_rate
        int bit_rate_tolerance
        int mb_decision
        
        int global_quality
        int compression_level
        
        int frame_number
        
        int qmin
        int qmax
        int rc_max_rate
        int rc_min_rate
        int rc_buffer_size
        float rc_max_available_vbv_use
        float rc_min_vbv_overflow_use
        
        AVRational time_base
        int ticks_per_frame
        
        
        AVCodec *codec

        # Video.
        int width
        int height
        int coded_width
        int coded_height

        AVPixelFormat pix_fmt
        AVRational sample_aspect_ratio
        int gop_size #the number of pictures in a group of pictures, or 0 for intra_only 
        int max_b_frames
        int has_b_frames

        # Audio.
        AVSampleFormat sample_fmt
        int sample_rate
        int channels
        int frame_size
        int channel_layout
        
        # TODO: get_buffer is deprecated for get_buffer2 in newer versions of FFmpeg
        int get_buffer(AVCodecContext *ctx, AVFrame *frame)
        void release_buffer(AVCodecContext *ctx, AVFrame *frame)
        
        # User Data
        void *opaque
    
    cdef int avcodec_copy_context(AVCodecContext *dst, const AVCodecContext *src)

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
    
    cdef char* av_get_profile_name(AVCodec *codec, int profile)

    cdef int avcodec_open2(
        AVCodecContext *ctx,
        AVCodec *codec,
        AVDictionary **options,
    )
    
    cdef int avcodec_is_open(AVCodecContext *ctx )
    cdef int avcodec_close(AVCodecContext *ctx)
    
    cdef int AV_NUM_DATA_POINTERS
    
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
        int format # Should be AVPixelFormat or AV...Format
        int key_frame # 0 or 1.
        
        int64_t pts
        int64_t pkt_pts
        int64_t pkt_dts
        
        int pkt_size
        
        uint8_t **base
        void *opaque
        
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
        
        int64_t pos

        void (*destruct)(AVPacket*)
    

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
    cdef void av_packet_unref(AVPacket *pkt)   
    cdef int av_copy_packet(AVPacket *dst, AVPacket *src)
    cdef int av_dup_packet(AVPacket *pkt)

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
    
     # TODO: avcodec_default_get_buffer is deprecated for avcodec_default_get_buffer2 in newer versions of FFmpeg
    cdef int avcodec_default_get_buffer(AVCodecContext *ctx, AVFrame *frame)
    cdef void avcodec_default_release_buffer(AVCodecContext *ctx, AVFrame *frame)
    
    
