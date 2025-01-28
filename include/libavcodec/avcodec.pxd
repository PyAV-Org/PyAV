from libc.stdint cimport int8_t, int64_t, uint16_t, uint32_t

cdef extern from "libavcodec/codec.h":
    struct AVCodecTag:
        pass

cdef extern from "libavcodec/codec_id.h":
    AVCodecID av_codec_get_id(const AVCodecTag *const *tags, uint32_t tag)


cdef extern from "libavcodec/packet.h" nogil:
    AVPacketSideData* av_packet_side_data_new(
        AVPacketSideData **sides,
        int *nb_sides,
        AVPacketSideDataType type,
        size_t size,
        int free_opaque
    )


cdef extern from "libavutil/channel_layout.h":
    ctypedef enum AVChannelOrder:
        AV_CHANNEL_ORDER_UNSPEC
        AV_CHANNEL_ORDER_NATIVE
        AV_CHANNEL_ORDER_CUSTOM
        AV_CHANNEL_ORDER_AMBISONIC

    ctypedef enum AVChannel:
        AV_CHAN_NONE = -1
        AV_CHAN_FRONT_LEFT
        AV_CHAN_FRONT_RIGHT
        AV_CHAN_FRONT_CENTER
        # ... other channel enum values ...

    ctypedef struct AVChannelCustom:
        AVChannel id
        char name[16]
        void *opaque

    ctypedef struct AVChannelLayout:
        AVChannelOrder order
        int nb_channels
        uint64_t mask
        # union:
        #     uint64_t mask
        #     AVChannelCustom *map
        void *opaque

    int av_channel_layout_default(AVChannelLayout *ch_layout, int nb_channels)
    int av_channel_layout_from_mask(AVChannelLayout *channel_layout, uint64_t mask)
    int av_channel_layout_from_string(AVChannelLayout *channel_layout, const char *str)
    void av_channel_layout_uninit(AVChannelLayout *channel_layout)
    int av_channel_layout_copy(AVChannelLayout *dst, const AVChannelLayout *src)
    int av_channel_layout_describe(const AVChannelLayout *channel_layout, char *buf, size_t buf_size)
    int av_channel_name(char *buf, size_t buf_size, AVChannel channel_id)
    int av_channel_description(char *buf, size_t buf_size, AVChannel channel_id)
    AVChannel av_channel_layout_channel_from_index(AVChannelLayout *channel_layout, unsigned int idx)


cdef extern from "libavcodec/avcodec.h" nogil:
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

    # AVCodec.capabilities
    cdef enum:
        AV_CODEC_CAP_DRAW_HORIZ_BAND
        AV_CODEC_CAP_DR1
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
        AV_CODEC_CAP_OTHER_THREADS
        AV_CODEC_CAP_VARIABLE_FRAME_SIZE
        AV_CODEC_CAP_AVOID_PROBING
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
        AV_CODEC_FLAG_RECON_FRAME
        AV_CODEC_FLAG_COPY_OPAQUE
        AV_CODEC_FLAG_FRAME_DURATION
        AV_CODEC_FLAG_PASS1
        AV_CODEC_FLAG_PASS2
        AV_CODEC_FLAG_LOOP_FILTER
        AV_CODEC_FLAG_GRAY
        AV_CODEC_FLAG_PSNR
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
        AV_CODEC_FLAG2_CHUNKS
        AV_CODEC_FLAG2_IGNORE_CROP
        AV_CODEC_FLAG2_SHOW_ALL
        AV_CODEC_FLAG2_EXPORT_MVS
        AV_CODEC_FLAG2_SKIP_MANUAL
        AV_CODEC_FLAG2_RO_FLUSH_NOOP

    cdef enum:
        AV_PKT_FLAG_KEY
        AV_PKT_FLAG_CORRUPT
        AV_PKT_FLAG_DISCARD
        AV_PKT_FLAG_TRUSTED
        AV_PKT_FLAG_DISPOSABLE

    cdef enum:
        AV_FRAME_FLAG_CORRUPT
        AV_FRAME_FLAG_KEY
        AV_FRAME_FLAG_DISCARD
        AV_FRAME_FLAG_INTERLACED

    cdef enum:
        FF_COMPLIANCE_VERY_STRICT
        FF_COMPLIANCE_STRICT
        FF_COMPLIANCE_NORMAL
        FF_COMPLIANCE_UNOFFICIAL
        FF_COMPLIANCE_EXPERIMENTAL

    cdef enum:
        FF_PROFILE_UNKNOWN = -99

    cdef enum AVCodecID:
        AV_CODEC_ID_NONE
        AV_CODEC_ID_MPEG2VIDEO
        AV_CODEC_ID_MPEG1VIDEO
        AV_CODEC_ID_PCM_ALAW
        AV_CODEC_ID_PCM_BLURAY
        AV_CODEC_ID_PCM_DVD
        AV_CODEC_ID_PCM_F16LE
        AV_CODEC_ID_PCM_F24LE
        AV_CODEC_ID_PCM_F32BE
        AV_CODEC_ID_PCM_F32LE
        AV_CODEC_ID_PCM_F64BE
        AV_CODEC_ID_PCM_F64LE
        AV_CODEC_ID_PCM_LXF
        AV_CODEC_ID_PCM_MULAW
        AV_CODEC_ID_PCM_S16BE
        AV_CODEC_ID_PCM_S16BE_PLANAR
        AV_CODEC_ID_PCM_S16LE
        AV_CODEC_ID_PCM_S16LE_PLANAR
        AV_CODEC_ID_PCM_S24BE
        AV_CODEC_ID_PCM_S24DAUD
        AV_CODEC_ID_PCM_S24LE
        AV_CODEC_ID_PCM_S24LE_PLANAR
        AV_CODEC_ID_PCM_S32BE
        AV_CODEC_ID_PCM_S32LE
        AV_CODEC_ID_PCM_S32LE_PLANAR
        AV_CODEC_ID_PCM_S64BE
        AV_CODEC_ID_PCM_S64LE
        AV_CODEC_ID_PCM_S8
        AV_CODEC_ID_PCM_S8_PLANAR
        AV_CODEC_ID_PCM_U16BE
        AV_CODEC_ID_PCM_U16LE
        AV_CODEC_ID_PCM_U24BE
        AV_CODEC_ID_PCM_U24LE
        AV_CODEC_ID_PCM_U32BE
        AV_CODEC_ID_PCM_U32LE
        AV_CODEC_ID_PCM_U8
        AV_CODEC_ID_PCM_VIDC

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

    cdef struct AVProfile:
        int profile
        char *name

    cdef struct AVCodecDescriptor:
        AVCodecID id
        char *name
        char *long_name
        int props
        char **mime_types
        AVProfile *profiles

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

        void* opaque

        int bit_rate
        int bit_rate_tolerance
        int mb_decision

        int bits_per_coded_sample
        int global_quality
        int compression_level

        int qmin
        int qmax
        int rc_max_rate
        int rc_min_rate
        int rc_buffer_size
        float rc_max_available_vbv_use
        float rc_min_vbv_overflow_use

        AVRational framerate
        AVRational pkt_timebase
        AVRational time_base

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
        AVPixelFormat sw_pix_fmt
        AVRational sample_aspect_ratio
        int gop_size  # The number of pictures in a group of pictures, or 0 for intra_only.
        int max_b_frames
        int has_b_frames
        AVColorRange color_range
        AVColorPrimaries color_primaries
        AVColorTransferCharacteristic color_trc
        AVColorSpace colorspace

        # Audio.
        AVSampleFormat sample_fmt
        int sample_rate
        AVChannelLayout ch_layout
        int frame_size

        #: .. todo:: ``get_buffer`` is deprecated for get_buffer2 in newer versions of FFmpeg.
        int get_buffer(AVCodecContext *ctx, AVFrame *frame)
        void release_buffer(AVCodecContext *ctx, AVFrame *frame)

        # Hardware acceleration
        AVHWAccel *hwaccel
        AVBufferRef *hw_device_ctx
        AVPixelFormat (*get_format)(AVCodecContext *s, const AVPixelFormat *fmt)

        # User Data
        void *opaque

    cdef AVCodecContext* avcodec_alloc_context3(AVCodec *codec)
    cdef void avcodec_free_context(AVCodecContext **ctx)

    cdef AVClass* avcodec_get_class()

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

    cdef int AV_NUM_DATA_POINTERS

    cdef enum AVPacketSideDataType:
        AV_PKT_DATA_PALETTE
        AV_PKT_DATA_NEW_EXTRADATA
        AV_PKT_DATA_PARAM_CHANGE
        AV_PKT_DATA_H263_MB_INFO
        AV_PKT_DATA_REPLAYGAIN
        AV_PKT_DATA_DISPLAYMATRIX
        AV_PKT_DATA_STEREO3D
        AV_PKT_DATA_AUDIO_SERVICE_TYPE
        AV_PKT_DATA_QUALITY_STATS
        AV_PKT_DATA_FALLBACK_TRACK
        AV_PKT_DATA_CPB_PROPERTIES
        AV_PKT_DATA_SKIP_SAMPLES
        AV_PKT_DATA_JP_DUALMONO
        AV_PKT_DATA_STRINGS_METADATA
        AV_PKT_DATA_SUBTITLE_POSITION
        AV_PKT_DATA_MATROSKA_BLOCKADDITIONAL
        AV_PKT_DATA_WEBVTT_IDENTIFIER
        AV_PKT_DATA_WEBVTT_SETTINGS
        AV_PKT_DATA_METADATA_UPDATE
        AV_PKT_DATA_MPEGTS_STREAM_ID
        AV_PKT_DATA_MASTERING_DISPLAY_METADATA
        AV_PKT_DATA_SPHERICAL
        AV_PKT_DATA_CONTENT_LIGHT_LEVEL
        AV_PKT_DATA_A53_CC
        AV_PKT_DATA_ENCRYPTION_INIT_INFO
        AV_PKT_DATA_ENCRYPTION_INFO
        AV_PKT_DATA_AFD
        AV_PKT_DATA_PRFT
        AV_PKT_DATA_ICC_PROFILE
        AV_PKT_DATA_DOVI_CONF
        AV_PKT_DATA_S12M_TIMECODE
        AV_PKT_DATA_DYNAMIC_HDR10_PLUS
        AV_PKT_DATA_NB

    cdef struct AVPacketSideData:
        uint8_t *data;
        size_t size;
        AVPacketSideDataType type;

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
        AV_FRAME_DATA_S12M_TIMECODE
        AV_FRAME_DATA_DYNAMIC_HDR_PLUS
        AV_FRAME_DATA_REGIONS_OF_INTEREST
        AV_FRAME_DATA_VIDEO_ENC_PARAMS
        AV_FRAME_DATA_SEI_UNREGISTERED
        AV_FRAME_DATA_FILM_GRAIN_PARAMS
        AV_FRAME_DATA_DETECTION_BBOXES
        AV_FRAME_DATA_DOVI_RPU_BUFFER
        AV_FRAME_DATA_DOVI_METADATA
        AV_FRAME_DATA_DYNAMIC_HDR_VIVID
        AV_FRAME_DATA_AMBIENT_VIEWING_ENVIRONMENT
        AV_FRAME_DATA_VIDEO_HINT

    cdef struct AVFrameSideData:
        AVFrameSideDataType type
        uint8_t *data
        int size
        AVDictionary *metadata

    # See: http://ffmpeg.org/doxygen/trunk/structAVFrame.html
    cdef struct AVFrame:
        uint8_t *data[4]
        int linesize[4]
        uint8_t **extended_data

        int format  # Should be AVPixelFormat or AVSampleFormat
        AVPictureType pict_type

        int width
        int height

        int nb_side_data
        AVFrameSideData **side_data

        int nb_samples
        int sample_rate

        AVChannelLayout ch_layout

        int64_t pts
        int64_t pkt_dts

        int pkt_size

        uint8_t **base
        void *opaque
        AVBufferRef *opaque_ref
        AVDictionary *metadata
        int flags
        int decode_error_flags
        AVColorRange color_range
        AVColorPrimaries color_primaries
        AVColorTransferCharacteristic color_trc
        AVColorSpace colorspace

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

        void *opaque
        AVBufferRef *opaque_ref


    cdef int avcodec_fill_audio_frame(
        AVFrame *frame,
        int nb_channels,
        AVSampleFormat sample_fmt,
        uint8_t *buf,
        int buf_size,
        int align
    )

    cdef void avcodec_free_frame(AVFrame **frame)

    cdef AVPacket* av_packet_alloc()
    cdef void av_packet_free(AVPacket **)
    cdef int av_new_packet(AVPacket*, int)
    cdef int av_packet_ref(AVPacket *dst, const AVPacket *src)
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
        uint8_t *data[4]
        int linesize[4]
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
        AVMediaType codec_type
        AVCodecID codec_id
        AVPacketSideData *coded_side_data
        int nb_coded_side_data
        uint8_t *extradata
        int extradata_size

    cdef int avcodec_parameters_copy(
        AVCodecParameters *dst,
        const AVCodecParameters *src
    )
    cdef int avcodec_parameters_from_context(
        AVCodecParameters *par,
        const AVCodecContext *codec,
    )
    cdef int avcodec_parameters_to_context(
        AVCodecContext *codec,
        const AVCodecParameters *par
    )
