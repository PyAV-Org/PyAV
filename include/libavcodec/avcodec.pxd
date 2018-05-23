from libc.stdint cimport uint8_t, uint16_t, uint32_t, uint64_t, int64_t


cdef extern from "libavcodec/avcodec.pyav.h" nogil:

    cdef int   avcodec_version()
    cdef char* avcodec_configuration()
    cdef char* avcodec_license()

    cdef int64_t AV_NOPTS_VALUE

    # AVCodecDescriptor.props
    cdef enum:
        AV_CODEC_PROP_INTRA_ONLY
        AV_CODEC_PROP_LOSSY
        AV_CODEC_PROP_LOSSLESS
        AV_CODEC_PROP_REORDER
        AV_CODEC_PROP_BITMAP_SUB
        AV_CODEC_PROP_TEXT_SUB

    #AVCodec.capabilities
    cdef enum:
        CODEC_CAP_DRAW_HORIZ_BAND
        CODEC_CAP_DR1
        CODEC_CAP_TRUNCATED
        CODEC_CAP_HWACCEL
        CODEC_CAP_DELAY
        CODEC_CAP_SMALL_LAST_FRAME
        CODEC_CAP_HWACCEL_VDPAU
        CODEC_CAP_SUBFRAMES
        CODEC_CAP_EXPERIMENTAL
        CODEC_CAP_CHANNEL_CONF
        CODEC_CAP_NEG_LINESIZES
        CODEC_CAP_FRAME_THREADS
        CODEC_CAP_SLICE_THREADS
        CODEC_CAP_PARAM_CHANGE
        CODEC_CAP_AUTO_THREADS
        CODEC_CAP_VARIABLE_FRAME_SIZE
        CODEC_CAP_INTRA_ONLY
        CODEC_CAP_LOSSLESS

    cdef enum:
        FF_THREAD_FRAME
        FF_THREAD_SLICE

    cdef enum:
        AV_CODEC_FLAG_GLOBAL_HEADER
        AV_CODEC_FLAG_QSCALE
        AV_CODEC_FLAG_TRUNCATED

    cdef enum:
        AV_PKT_FLAG_KEY
        AV_PKT_FLAG_CORRUPT

    cdef enum:
        AV_FRAME_FLAG_CORRUPT

    cdef enum:
        FF_COMPLIANCE_VERY_STRICT
        FF_COMPLIANCE_STRICT
        FF_COMPLIANCE_NORMAL
        FF_COMPLIANCE_UNOFFICIAL
        FF_COMPLIANCE_EXPERIMENTAL

    cdef enum AVCodecID:
        AV_CODEC_ID_NONE
        AV_CODEC_ID_MPEG2VIDEO
        AV_CODEC_ID_MPEG1VIDEO

    cdef enum AVDiscard:
        AVDISCARD_NONE
        AVDISCARD_DEFAULT
        AVDISCARD_NONREF
        AVDISCARD_BIDIR
        AVDISCARD_NONINTRA
        AVDISCARD_NONKEY
        AVDISCARD_ALL

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


    cdef int av_codec_is_encoder(AVCodec*)
    cdef int av_codec_is_decoder(AVCodec*)

    cdef struct AVCodecDescriptor:
        AVCodecID id
        char *name
        char *long_name
        int props
        char **mime_types

    AVCodecDescriptor* avcodec_descriptor_get(AVCodecID)


    cdef struct AVCodecContext:

        AVClass *av_class

        AVMediaType codec_type
        char codec_name[32]
        unsigned int codec_tag
        AVCodecID codec_id

        int flags
        int thread_count
        int thread_type

        int profile
        AVDiscard skip_frame

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

        AVRational framerate
        AVRational time_base
        int ticks_per_frame

        int extradata_size
        uint8_t *extradata

        int delay

        AVCodec *codec

        # Video.
        int width
        int height
        int coded_width
        int coded_height

        AVPixelFormat pix_fmt
        AVRational sample_aspect_ratio
        int gop_size # The number of pictures in a group of pictures, or 0 for intra_only.
        int max_b_frames
        int has_b_frames

        # Audio.
        AVSampleFormat sample_fmt
        int sample_rate
        int channels
        int frame_size
        int channel_layout

        #: .. todo:: ``get_buffer`` is deprecated for get_buffer2 in newer versions of FFmpeg.
        int get_buffer(AVCodecContext *ctx, AVFrame *frame)
        void release_buffer(AVCodecContext *ctx, AVFrame *frame)

        # Hardware acceleration
        AVBufferRef *hw_device_ctx
        AVPixelFormat (*get_format)(AVCodecContext *s, const AVPixelFormat * fmt)

        # User Data
        void *opaque

    cdef AVCodecContext* avcodec_alloc_context3(AVCodec *codec)
    cdef void avcodec_free_context(AVCodecContext **ctx)

    cdef AVClass* avcodec_get_class()
    cdef int avcodec_copy_context(AVCodecContext *dst, const AVCodecContext *src)

    # Hardware acceleration
    enum:
        AV_CODEC_HW_CONFIG_METHOD_HW_DEVICE_CTX = 0x01,
        AV_CODEC_HW_CONFIG_METHOD_HW_FRAMES_CTX = 0x02,
        AV_CODEC_HW_CONFIG_METHOD_INTERNAL      = 0x04,
        AV_CODEC_HW_CONFIG_METHOD_AD_HOC        = 0x08,

    cdef struct AVCodecHWConfig:
        AVPixelFormat pix_fmt;
        int methods;
        AVHWDeviceType device_type;

    cdef const AVCodecHWConfig* avcodec_get_hw_config(const AVCodec *codec, int index)

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

    # See: http://ffmpeg.org/doxygen/trunk/structAVFrame.html
    cdef struct AVFrame:
        uint8_t *data[4];
        int linesize[4];
        uint8_t **extended_data

        int format # Should be AVPixelFormat or AVSampleFormat
        int key_frame # 0 or 1.
        AVPictureType pict_type

        int interlaced_frame # 0 or 1.

        int width
        int height

        int nb_samples # Audio samples
        int sample_rate # Audio Sample rate
        int channels # Number of audio channels
        int channel_layout # Audio channel_layout

        int64_t pts
        int64_t pkt_dts

        int pkt_size

        uint8_t **base
        void *opaque
        AVDictionary *metadata
        int flags
        int decode_error_flags


    cdef AVFrame* avcodec_alloc_frame()

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


    cdef int avcodec_fill_audio_frame(
        AVFrame *frame,
        int nb_channels,
        AVSampleFormat sample_fmt,
        uint8_t *buf,
        int buf_size,
        int align
    )

    cdef void avcodec_free_frame(AVFrame **frame)

    cdef void av_init_packet(AVPacket*)
    cdef int av_new_packet(AVPacket*, int)
    cdef int av_packet_ref(AVPacket *dst, const AVPacket *src)
    cdef void av_packet_unref(AVPacket *pkt)

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
        uint8_t *data[4];
        int linesize[4];
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

    cdef void avcodec_flush_buffers(AVCodecContext *ctx)

     # TODO: avcodec_default_get_buffer is deprecated for avcodec_default_get_buffer2 in newer versions of FFmpeg
    cdef int avcodec_default_get_buffer(AVCodecContext *ctx, AVFrame *frame)
    cdef void avcodec_default_release_buffer(AVCodecContext *ctx, AVFrame *frame)

    # === New-style Transcoding
    cdef int avcodec_send_packet(AVCodecContext *avctx, AVPacket *packet)
    cdef int avcodec_receive_frame(AVCodecContext *avctx, AVFrame *frame)
    cdef int avcodec_send_frame(AVCodecContext *avctx, AVFrame *frame)
    cdef int avcodec_receive_packet(AVCodecContext *avctx, AVPacket *avpkt)

    # === Parsers

    cdef struct AVCodecParser:
        int codec_ids[5]

    cdef AVCodecParser* av_parser_next(AVCodecParser *c)

    cdef struct AVCodecParserContext:
        pass

    cdef AVCodecParserContext *av_parser_init(int codec_id)
    cdef int av_parser_parse2(
        AVCodecParserContext *s,
        AVCodecContext *avctx,
        uint8_t **poutbuf, int *poutbuf_size,
        const uint8_t *buf, int buf_size,
        int64_t pts, int64_t dts,
        int64_t pos
    )
    cdef int av_parser_change(
        AVCodecParserContext *s,
        AVCodecContext *avctx,
        uint8_t **poutbuf, int *poutbuf_size,
        const uint8_t *buf, int buf_size,
        int keyframe
    )
    cdef void av_parser_close(AVCodecParserContext *s)

    # custom
    cdef set pyav_get_available_codecs()
