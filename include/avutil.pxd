from libc.stdint cimport int16_t, int32_t, int64_t, uint8_t, uint16_t, uint32_t, uint64_t


cdef extern from "libavutil/audio_fifo.h" nogil:
    cdef struct AVAudioFifo:
        pass
    cdef void av_audio_fifo_free(AVAudioFifo *af)
    cdef AVAudioFifo* av_audio_fifo_alloc(
        AVSampleFormat sample_fmt, int channels, int nb_samples
    )
    cdef int av_audio_fifo_write(AVAudioFifo *af, void **data, int nb_samples)
    cdef int av_audio_fifo_read(AVAudioFifo *af, void **data, int nb_samples)
    cdef int av_audio_fifo_size(AVAudioFifo *af)

cdef extern from "libavutil/avutil.h" nogil:
    cdef const char* av_version_info()
    cdef int avutil_version()
    cdef char* avutil_configuration()
    cdef char* avutil_license()

    cdef enum AVPictureType:
        AV_PICTURE_TYPE_NONE
        AV_PICTURE_TYPE_I
        AV_PICTURE_TYPE_P
        AV_PICTURE_TYPE_B
        AV_PICTURE_TYPE_S
        AV_PICTURE_TYPE_SI
        AV_PICTURE_TYPE_SP
        AV_PICTURE_TYPE_BI

    cdef enum AVPixelFormat:
        AV_PIX_FMT_NONE
        AV_PIX_FMT_YUV420P

    cdef enum AVColorSpace:
        AVCOL_SPC_RGB
        AVCOL_SPC_BT709
        AVCOL_SPC_UNSPECIFIED
        AVCOL_SPC_RESERVED
        AVCOL_SPC_FCC
        AVCOL_SPC_BT470BG
        AVCOL_SPC_SMPTE170M
        AVCOL_SPC_SMPTE240M
        AVCOL_SPC_YCOCG
        AVCOL_SPC_BT2020_NCL
        AVCOL_SPC_BT2020_CL
        AVCOL_SPC_NB

    cdef enum AVColorRange:
        AVCOL_RANGE_UNSPECIFIED
        AVCOL_RANGE_MPEG
        AVCOL_RANGE_JPEG
        AVCOL_RANGE_NB

    cdef enum AVColorPrimaries:
        AVCOL_PRI_BT709
        AVCOL_PRI_UNSPECIFIED
        AVCOL_PRI_BT470M
        AVCOL_PRI_BT470BG
        AVCOL_PRI_SMPTE170M
        AVCOL_PRI_SMPTE240M
        AVCOL_PRI_FILM
        AVCOL_PRI_BT2020
        AVCOL_PRI_SMPTE428
        AVCOL_PRI_SMPTEST428_1
        AVCOL_PRI_SMPTE431
        AVCOL_PRI_SMPTE432
        AVCOL_PRI_EBU3213
        AVCOL_PRI_JEDEC_P22

    cdef enum AVColorTransferCharacteristic:
        AVCOL_TRC_BT709
        AVCOL_TRC_UNSPECIFIED
        AVCOL_TRC_GAMMA22
        AVCOL_TRC_GAMMA28
        AVCOL_TRC_SMPTE170M
        AVCOL_TRC_SMPTE240M
        AVCOL_TRC_LINEAR
        AVCOL_TRC_LOG
        AVCOL_TRC_LOG_SQRT
        AVCOL_TRC_IEC61966_2_4
        AVCOL_TRC_BT1361_ECG
        AVCOL_TRC_IEC61966_2_1
        AVCOL_TRC_BT2020_10
        AVCOL_TRC_BT2020_12
        AVCOL_TRC_SMPTE2084
        AVCOL_TRC_SMPTEST2084
        AVCOL_TRC_SMPTE428
        AVCOL_TRC_SMPTEST428_1
        AVCOL_TRC_ARIB_STD_B67

    cdef void* av_malloc(size_t size)
    cdef void* av_mallocz(size_t size)
    cdef void* av_realloc(void *ptr, size_t size)
    cdef void av_free(void *ptr)
    cdef void av_freep(void *ptr)
    cdef int av_get_bytes_per_sample(AVSampleFormat sample_fmt)
    cdef int av_samples_get_buffer_size(
        int *linesize,
        int nb_channels,
        int nb_samples,
        AVSampleFormat sample_fmt,
        int align
    )
    ctypedef struct AVRational:
        int num
        int den
    cdef int64_t av_rescale_q(int64_t a, AVRational bq, AVRational cq)
    cdef int64_t av_rescale(int64_t a, int64_t b, int64_t c)
    cdef const char* av_get_media_type_string(AVMediaType media_type)

cdef extern from "libavutil/buffer.h" nogil:
    AVBufferRef *av_buffer_create(uint8_t *data, size_t size, void (*free)(void *opaque, uint8_t *data), void *opaque, int flags)
    AVBufferRef* av_buffer_ref(AVBufferRef *buf)
    void av_buffer_unref(AVBufferRef **buf)
    cdef struct AVBuffer:
        uint8_t *data
        int size
        void (*free)(void *opaque, uint8_t *data)
        void *opaque
        int flags
    cdef struct AVBufferRef:
        AVBuffer *buffer
        uint8_t *data
        int size

cdef extern from "libavutil/dict.h" nogil:
    # See: http://ffmpeg.org/doxygen/trunk/structAVDictionary.html
    ctypedef struct AVDictionary:
        pass
    # See: http://ffmpeg.org/doxygen/trunk/structAVDictionaryEntry.html
    ctypedef struct AVDictionaryEntry:
        char *key
        char *value
    cdef int AV_DICT_IGNORE_SUFFIX
    cdef void av_dict_free(AVDictionary **)
    cdef AVDictionaryEntry* av_dict_get(
        AVDictionary *dict, char *key, AVDictionaryEntry *prev, int flags
    )
    cdef int av_dict_set(
        AVDictionary **pm, const char *key, const char *value, int flags
    )
    cdef int av_dict_count(AVDictionary *m)
    cdef int av_dict_copy(AVDictionary **dst, AVDictionary *src, int flags)

cdef extern from "libavutil/display.h" nogil:
    cdef double av_display_rotation_get(const int32_t matrix[9])

cdef extern from "libavutil/error.h" nogil:
    cdef int AVERROR_BSF_NOT_FOUND
    cdef int AVERROR_BUG
    cdef int AVERROR_BUFFER_TOO_SMALL
    cdef int AVERROR_DECODER_NOT_FOUND
    cdef int AVERROR_DEMUXER_NOT_FOUND
    cdef int AVERROR_ENCODER_NOT_FOUND
    cdef int AVERROR_EOF
    cdef int AVERROR_EXIT
    cdef int AVERROR_EXTERNAL
    cdef int AVERROR_FILTER_NOT_FOUND
    cdef int AVERROR_INVALIDDATA
    cdef int AVERROR_MUXER_NOT_FOUND
    cdef int AVERROR_OPTION_NOT_FOUND
    cdef int AVERROR_PATCHWELCOME
    cdef int AVERROR_PROTOCOL_NOT_FOUND
    cdef int AVERROR_UNKNOWN
    cdef int AVERROR_EXPERIMENTAL
    cdef int AVERROR_INPUT_CHANGED
    cdef int AVERROR_OUTPUT_CHANGED
    cdef int AVERROR_HTTP_BAD_REQUEST
    cdef int AVERROR_HTTP_UNAUTHORIZED
    cdef int AVERROR_HTTP_FORBIDDEN
    cdef int AVERROR_HTTP_NOT_FOUND
    cdef int AVERROR_HTTP_OTHER_4XX
    cdef int AVERROR_HTTP_SERVER_ERROR
    cdef int AV_ERROR_MAX_STRING_SIZE
    cdef int av_strerror(int errno, char *output, size_t output_size)
    cdef char* av_err2str(int errnum)

cdef extern from "libavutil/frame.h" nogil:
    cdef AVFrame* av_frame_alloc()
    cdef void av_frame_free(AVFrame**)
    cdef int av_frame_ref(AVFrame *dst, const AVFrame *src)
    cdef void av_frame_unref(AVFrame *frame)
    cdef int av_frame_get_buffer(AVFrame *frame, int align)
    cdef int av_frame_make_writable(AVFrame *frame)
    cdef int av_frame_copy_props(AVFrame *dst, const AVFrame *src)
    cdef AVFrameSideData* av_frame_get_side_data(AVFrame *frame, AVFrameSideDataType type)

cdef extern from "libavutil/hwcontext.h" nogil:
    enum AVHWDeviceType:
        AV_HWDEVICE_TYPE_NONE
        AV_HWDEVICE_TYPE_VDPAU
        AV_HWDEVICE_TYPE_CUDA
        AV_HWDEVICE_TYPE_VAAPI
        AV_HWDEVICE_TYPE_DXVA2
        AV_HWDEVICE_TYPE_QSV
        AV_HWDEVICE_TYPE_VIDEOTOOLBOX
        AV_HWDEVICE_TYPE_D3D11VA
        AV_HWDEVICE_TYPE_DRM
        AV_HWDEVICE_TYPE_OPENCL
        AV_HWDEVICE_TYPE_MEDIACODEC
        AV_HWDEVICE_TYPE_VULKAN
        AV_HWDEVICE_TYPE_D3D12VA

    ctypedef struct AVHWFramesContext:
        const void *av_class
        AVBufferRef *device_ref
        void *device_ctx
        void *hwctx
        AVPixelFormat format
        AVPixelFormat sw_format
        int width
        int height

    cdef int av_hwdevice_ctx_create(AVBufferRef **device_ctx, AVHWDeviceType type, const char *device, AVDictionary *opts, int flags)
    cdef AVHWDeviceType av_hwdevice_find_type_by_name(const char *name)
    cdef const char *av_hwdevice_get_type_name(AVHWDeviceType type)
    cdef AVHWDeviceType av_hwdevice_iterate_types(AVHWDeviceType prev)
    cdef int av_hwframe_transfer_data(AVFrame *dst, const AVFrame *src, int flags)

    cdef AVBufferRef *av_hwframe_ctx_alloc(AVBufferRef *device_ref)
    cdef int av_hwframe_ctx_init(AVBufferRef *ref)

cdef extern from "libavutil/imgutils.h" nogil:
    cdef int av_image_alloc(
        uint8_t *pointers[4],
        int linesizes[4],
        int width,
        int height,
        AVPixelFormat pix_fmt,
        int align
    )
    cdef int av_image_fill_pointers(
        uint8_t *pointers[4],
        AVPixelFormat pix_fmt,
        int height,
        uint8_t *ptr,
        const int linesizes[4]
    )

cdef extern from "libavutil/log.h" nogil:
    cdef struct AVClass:
        const char *class_name
        const char *(*item_name)(void*) nogil
        const AVOption *option

    cdef enum:
        AV_LOG_QUIET
        AV_LOG_PANIC
        AV_LOG_FATAL
        AV_LOG_ERROR
        AV_LOG_WARNING
        AV_LOG_INFO
        AV_LOG_VERBOSE
        AV_LOG_DEBUG
        AV_LOG_TRACE

    void av_log(void *ptr, int level, const char *fmt, ...)
    ctypedef void(*av_log_callback)(void *, int, const char *, va_list)
    void av_log_default_callback(void *, int, const char *, va_list)
    void av_log_set_callback (av_log_callback callback)
    void av_log_set_level(int level)

cdef extern from "libavutil/motion_vector.h" nogil:
    cdef struct AVMotionVector:
        int32_t source
        uint8_t w
        uint8_t h
        int16_t src_x
        int16_t src_y
        int16_t dst_x
        int16_t dst_y
        uint64_t flags
        int32_t motion_x
        int32_t motion_y
        uint16_t motion_scale

cdef extern from "libavutil/opt.h" nogil:
    cdef enum AVOptionType:
        AV_OPT_TYPE_FLAGS
        AV_OPT_TYPE_INT
        AV_OPT_TYPE_INT64
        AV_OPT_TYPE_DOUBLE
        AV_OPT_TYPE_FLOAT
        AV_OPT_TYPE_STRING
        AV_OPT_TYPE_RATIONAL
        AV_OPT_TYPE_BINARY
        AV_OPT_TYPE_DICT
        AV_OPT_TYPE_UINT64
        AV_OPT_TYPE_CONST
        AV_OPT_TYPE_IMAGE_SIZE
        AV_OPT_TYPE_PIXEL_FMT
        AV_OPT_TYPE_SAMPLE_FMT
        AV_OPT_TYPE_VIDEO_RATE
        AV_OPT_TYPE_DURATION
        AV_OPT_TYPE_COLOR
        AV_OPT_TYPE_CHLAYOUT
        AV_OPT_TYPE_BOOL

    cdef struct AVOption_default_val:
        int64_t i64
        double dbl
        const char *str
        AVRational q

    cdef enum:
        AV_OPT_FLAG_ENCODING_PARAM
        AV_OPT_FLAG_DECODING_PARAM
        AV_OPT_FLAG_AUDIO_PARAM
        AV_OPT_FLAG_VIDEO_PARAM
        AV_OPT_FLAG_SUBTITLE_PARAM
        AV_OPT_FLAG_EXPORT
        AV_OPT_FLAG_READONLY
        AV_OPT_FLAG_FILTERING_PARAM

    cdef struct AVOption:
        const char *name
        const char *help
        AVOptionType type
        int offset
        AVOption_default_val default_val
        double min
        double max
        int flags
        const char *unit

cdef extern from "libavutil/pixdesc.h" nogil:
    # See: http://ffmpeg.org/doxygen/trunk/structAVComponentDescriptor.html
    cdef struct AVComponentDescriptor:
        unsigned int plane
        unsigned int step
        unsigned int offset
        unsigned int shift
        unsigned int depth

    cdef enum AVPixFmtFlags:
        AV_PIX_FMT_FLAG_BE
        AV_PIX_FMT_FLAG_PAL
        AV_PIX_FMT_FLAG_BITSTREAM
        AV_PIX_FMT_FLAG_PLANAR
        AV_PIX_FMT_FLAG_RGB
        AV_PIX_FMT_FLAG_BAYER

    # See: http://ffmpeg.org/doxygen/trunk/structAVPixFmtDescriptor.html
    cdef struct AVPixFmtDescriptor:
        const char *name
        uint8_t nb_components
        uint8_t log2_chroma_w
        uint8_t log2_chroma_h
        uint8_t flags
        AVComponentDescriptor comp[4]

    cdef const AVPixFmtDescriptor* av_pix_fmt_desc_get(AVPixelFormat pix_fmt)
    cdef const AVPixFmtDescriptor* av_pix_fmt_desc_next(const AVPixFmtDescriptor *prev)
    cdef char * av_get_pix_fmt_name(AVPixelFormat pix_fmt)
    cdef AVPixelFormat av_get_pix_fmt(char* name)
    int av_get_bits_per_pixel(const AVPixFmtDescriptor *pixdesc)
    int av_get_padded_bits_per_pixel(const AVPixFmtDescriptor *pixdesc)

cdef extern from "libavutil/rational.h" nogil:
    cdef int av_reduce(int *dst_num, int *dst_den, int64_t num, int64_t den, int64_t max)

cdef extern from "libavutil/samplefmt.h" nogil:
    cdef enum AVSampleFormat:
        AV_SAMPLE_FMT_U8
        AV_SAMPLE_FMT_S16
        AV_SAMPLE_FMT_S32
        AV_SAMPLE_FMT_FLT
        AV_SAMPLE_FMT_DBL

    cdef AVSampleFormat av_get_sample_fmt(char* name)
    cdef char *av_get_sample_fmt_name(AVSampleFormat sample_fmt)
    cdef int av_get_bytes_per_sample(AVSampleFormat sample_fmt)
    cdef int av_sample_fmt_is_planar(AVSampleFormat sample_fmt)
    cdef AVSampleFormat av_get_packed_sample_fmt(AVSampleFormat sample_fmt)
    cdef AVSampleFormat av_get_planar_sample_fmt(AVSampleFormat sample_fmt)
    cdef int av_samples_get_buffer_size(
        int *linesize,
        int nb_channels,
        int nb_samples,
        AVSampleFormat sample_fmt,
        int align
    )

cdef extern from "libavutil/video_enc_params.h" nogil:
    cdef enum AVVideoEncParamsType:
        AV_VIDEO_ENC_PARAMS_NONE
        AV_VIDEO_ENC_PARAMS_VP9
        AV_VIDEO_ENC_PARAMS_H264
        AV_VIDEO_ENC_PARAMS_MPEG2

    cdef struct AVVideoEncParams:
        uint32_t nb_blocks
        size_t blocks_offset
        size_t block_size
        AVVideoEncParamsType type
        int32_t qp
        int32_t delta_qp[4][2]

    cdef struct AVVideoBlockParams:
        int32_t src_x
        int32_t src_y
        int32_t w
        int32_t h
        int32_t delta_qp

cdef extern from "stdarg.h" nogil:
    ctypedef struct va_list:
        pass
