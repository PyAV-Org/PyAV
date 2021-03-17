from libc.stdint cimport (
    uint8_t, int8_t,
    uint16_t, int16_t,
    uint32_t, int32_t,
    uint64_t, int64_t
)


cdef extern from "libavcodec/avcodec.h" nogil:

    # custom
    cdef set pyav_get_available_codecs()

    cdef int   avcodec_version()
    cdef char* avcodec_configuration()
    cdef char* avcodec_license()

    cdef size_t AV_INPUT_BUFFER_PADDING_SIZE
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
        AV_CODEC_CAP_DRAW_HORIZ_BAND
        AV_CODEC_CAP_DR1
        AV_CODEC_CAP_TRUNCATED
        # AV_CODEC_CAP_HWACCEL
        AV_CODEC_CAP_DELAY
        AV_CODEC_CAP_SMALL_LAST_FRAME
        # AV_CODEC_CAP_HWACCEL_VDPAU
        AV_CODEC_CAP_SUBFRAMES
        AV_CODEC_CAP_EXPERIMENTAL
        AV_CODEC_CAP_CHANNEL_CONF
        # AV_CODEC_CAP_NEG_LINESIZES
        AV_CODEC_CAP_FRAME_THREADS
        AV_CODEC_CAP_SLICE_THREADS
        AV_CODEC_CAP_PARAM_CHANGE
        AV_CODEC_CAP_AUTO_THREADS
        AV_CODEC_CAP_VARIABLE_FRAME_SIZE
        AV_CODEC_CAP_AVOID_PROBING
        AV_CODEC_CAP_INTRA_ONLY
        AV_CODEC_CAP_LOSSLESS
        AV_CODEC_CAP_HARDWARE
        AV_CODEC_CAP_HYBRID
        AV_CODEC_CAP_ENCODER_REORDERED_OPAQUE

    cdef enum:
        FF_THREAD_FRAME
        FF_THREAD_SLICE

    cdef enum:
        AV_CODEC_FLAG_UNALIGNED
        AV_CODEC_FLAG_QSCALE
        AV_CODEC_FLAG_4MV
        AV_CODEC_FLAG_OUTPUT_CORRUPT
        AV_CODEC_FLAG_QPEL
        AV_CODEC_FLAG_DROPCHANGED
        AV_CODEC_FLAG_PASS1
        AV_CODEC_FLAG_PASS2
        AV_CODEC_FLAG_LOOP_FILTER
        AV_CODEC_FLAG_GRAY
        AV_CODEC_FLAG_PSNR
        AV_CODEC_FLAG_TRUNCATED
        AV_CODEC_FLAG_INTERLACED_DCT
        AV_CODEC_FLAG_LOW_DELAY
        AV_CODEC_FLAG_GLOBAL_HEADER
        AV_CODEC_FLAG_BITEXACT
        AV_CODEC_FLAG_AC_PRED
        AV_CODEC_FLAG_INTERLACED_ME
        AV_CODEC_FLAG_CLOSED_GOP

    cdef enum:
        AV_CODEC_FLAG2_FAST
        AV_CODEC_FLAG2_NO_OUTPUT
        AV_CODEC_FLAG2_LOCAL_HEADER
        AV_CODEC_FLAG2_DROP_FRAME_TIMECODE
        AV_CODEC_FLAG2_CHUNKS
        AV_CODEC_FLAG2_IGNORE_CROP
        AV_CODEC_FLAG2_SHOW_ALL
        AV_CODEC_FLAG2_EXPORT_MVS
        AV_CODEC_FLAG2_SKIP_MANUAL
        AV_CODEC_FLAG2_RO_FLUSH_NOOP

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
        int flags2

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

        # User Data
        void *opaque

    cdef AVCodecContext* avcodec_alloc_context3(AVCodec *codec)
    cdef void avcodec_free_context(AVCodecContext **ctx)

    cdef AVClass* avcodec_get_class()
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

    cdef const AVCodec* av_codec_iterate(void **opaque)

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

    cdef enum AVFrameSideDataType:
        AV_FRAME_DATA_PANSCAN
        AV_FRAME_DATA_A53_CC
        AV_FRAME_DATA_STEREO3D
        AV_FRAME_DATA_MATRIXENCODING
        AV_FRAME_DATA_DOWNMIX_INFO
        AV_FRAME_DATA_REPLAYGAIN
        AV_FRAME_DATA_DISPLAYMATRIX
        AV_FRAME_DATA_AFD
        AV_FRAME_DATA_MOTION_VECTORS
        AV_FRAME_DATA_SKIP_SAMPLES
        AV_FRAME_DATA_AUDIO_SERVICE_TYPE
        AV_FRAME_DATA_MASTERING_DISPLAY_METADATA
        AV_FRAME_DATA_GOP_TIMECODE
        AV_FRAME_DATA_SPHERICAL
        AV_FRAME_DATA_CONTENT_LIGHT_LEVEL
        AV_FRAME_DATA_ICC_PROFILE
        AV_FRAME_DATA_QP_TABLE_PROPERTIES
        AV_FRAME_DATA_QP_TABLE_DATA

    cdef struct AVFrameSideData:
        AVFrameSideDataType type
        uint8_t *data
        int size
        AVDictionary *metadata

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

        int nb_side_data
        AVFrameSideData **side_data

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
    cdef void av_packet_rescale_ts(AVPacket *pkt, AVRational src_tb, AVRational dst_tb)

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


    cdef struct AVCodecParameters:
        pass

    cdef int avcodec_parameters_from_context(
        AVCodecParameters *par,
        const AVCodecContext *codec,
    )

