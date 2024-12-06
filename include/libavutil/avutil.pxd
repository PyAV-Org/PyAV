from libc.stdint cimport int64_t, uint8_t, uint64_t, int32_t


cdef extern from "libavutil/mathematics.h" nogil:
    pass

cdef extern from "libavutil/display.h" nogil:
    cdef double av_display_rotation_get(const int32_t matrix[9])

cdef extern from "libavutil/rational.h" nogil:
    cdef int av_reduce(int *dst_num, int *dst_den, int64_t num, int64_t den, int64_t max)

cdef extern from "libavutil/avutil.h" nogil:

    cdef const char* av_version_info()
    cdef int   avutil_version()
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
        AV_PIX_FMT_RGB24
        PIX_FMT_RGB24
        PIX_FMT_RGBA

    cdef enum AVRounding:
        AV_ROUND_ZERO
        AV_ROUND_INF
        AV_ROUND_DOWN
        AV_ROUND_UP
        AV_ROUND_NEAR_INF
        # This is nice, but only in FFMpeg:
        # AV_ROUND_PASS_MINMAX

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
        AVCOL_PRI_RESERVED0
        AVCOL_PRI_BT709
        AVCOL_PRI_UNSPECIFIED
        AVCOL_PRI_RESERVED
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
        AVCOL_PRI_NB

    cdef enum AVColorTransferCharacteristic:
        AVCOL_TRC_RESERVED0
        AVCOL_TRC_BT709
        AVCOL_TRC_UNSPECIFIED
        AVCOL_TRC_RESERVED
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
        AVCOL_TRC_NB

    cdef double M_PI

    cdef void* av_malloc(size_t size)
    cdef void *av_calloc(size_t nmemb, size_t size)
    cdef void *av_realloc(void *ptr, size_t size)

    cdef void av_freep(void *ptr)

    cdef int av_get_bytes_per_sample(AVSampleFormat sample_fmt)

    cdef int av_samples_get_buffer_size(
        int *linesize,
        int nb_channels,
        int nb_samples,
        AVSampleFormat sample_fmt,
        int align
    )

    # See: http://ffmpeg.org/doxygen/trunk/structAVRational.html
    ctypedef struct AVRational:
        int num
        int den

    cdef AVRational AV_TIME_BASE_Q

    # Rescales from one time base to another
    cdef int64_t av_rescale_q(
        int64_t a,  # time stamp
        AVRational bq,  # source time base
        AVRational cq   # target time base
    )

    # Rescale a 64-bit integer with specified rounding.
    # A simple a*b/c isn't possible as it can overflow
    cdef int64_t av_rescale_rnd(
        int64_t a,
        int64_t b,
        int64_t c,
        int r  # should be AVRounding, but then we can't use bitwise logic.
    )

    cdef int64_t av_rescale_q_rnd(
        int64_t a,
        AVRational bq,
        AVRational cq,
        int r  # should be AVRounding, but then we can't use bitwise logic.
    )

    cdef int64_t av_rescale(
        int64_t a,
        int64_t b,
        int64_t c
    )

    cdef char* av_strdup(char *s)

    cdef int av_opt_set_int(
        void *obj,
        char *name,
        int64_t value,
        int search_flags
    )

    cdef const char* av_get_media_type_string(AVMediaType media_type)

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
        AV_PIX_FMT_FLAG_HWACCEL
        AV_PIX_FMT_FLAG_PLANAR
        AV_PIX_FMT_FLAG_RGB
        AV_PIX_FMT_FLAG_PSEUDOPAL
        AV_PIX_FMT_FLAG_ALPHA
        AV_PIX_FMT_FLAG_BAYER
        AV_PIX_FMT_FLAG_FLOAT

    # See: http://ffmpeg.org/doxygen/trunk/structAVPixFmtDescriptor.html
    cdef struct AVPixFmtDescriptor:
        const char *name
        uint8_t nb_components
        uint8_t log2_chroma_w
        uint8_t log2_chroma_h
        uint8_t flags
        AVComponentDescriptor comp[4]

    cdef AVPixFmtDescriptor* av_pix_fmt_desc_get(AVPixelFormat pix_fmt)
    cdef AVPixFmtDescriptor* av_pix_fmt_desc_next(AVPixFmtDescriptor *prev)

    cdef char * av_get_pix_fmt_name(AVPixelFormat pix_fmt)
    cdef AVPixelFormat av_get_pix_fmt(char* name)

    int av_get_bits_per_pixel(AVPixFmtDescriptor *pixdesc)
    int av_get_padded_bits_per_pixel(AVPixFmtDescriptor *pixdesc)


cdef extern from "libavutil/channel_layout.h" nogil:

    # Layouts.
    cdef uint64_t av_get_channel_layout(char* name)
    cdef int av_get_channel_layout_nb_channels(uint64_t channel_layout)
    cdef int64_t av_get_default_channel_layout(int nb_channels)

    # Channels.
    cdef uint64_t av_channel_layout_extract_channel(uint64_t layout, int index)
    cdef char* av_get_channel_name(uint64_t channel)
    cdef char* av_get_channel_description(uint64_t channel)


cdef extern from "libavutil/audio_fifo.h" nogil:

    cdef struct AVAudioFifo:
        pass

    cdef void av_audio_fifo_free(AVAudioFifo *af)

    cdef AVAudioFifo* av_audio_fifo_alloc(
         AVSampleFormat sample_fmt,
         int channels,
         int nb_samples
    )

    cdef int av_audio_fifo_write(
        AVAudioFifo *af,
        void **data,
        int nb_samples
    )

    cdef int av_audio_fifo_read(
        AVAudioFifo *af,
        void **data,
        int nb_samples
    )

    cdef int av_audio_fifo_size(AVAudioFifo *af)
    cdef int av_audio_fifo_space (AVAudioFifo *af)


cdef extern from "stdarg.h" nogil:
    # For logging. Should really be in another PXD.
    ctypedef struct va_list:
        pass


cdef extern from "Python.h" nogil:
    # For logging. See av/logging.pyx for an explanation.
    cdef int Py_AddPendingCall(void *, void *)
    void PyErr_PrintEx(int set_sys_last_vars)
    int Py_IsInitialized()
    void PyErr_Display(object, object, object)


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
    cdef int av_image_fill_linesizes(
        int linesizes[4],
        AVPixelFormat pix_fmt,
        int width,
    )


cdef extern from "libavutil/log.h" nogil:

    cdef enum AVClassCategory:
        AV_CLASS_CATEGORY_NA
        AV_CLASS_CATEGORY_INPUT
        AV_CLASS_CATEGORY_OUTPUT
        AV_CLASS_CATEGORY_MUXER
        AV_CLASS_CATEGORY_DEMUXER
        AV_CLASS_CATEGORY_ENCODER
        AV_CLASS_CATEGORY_DECODER
        AV_CLASS_CATEGORY_FILTER
        AV_CLASS_CATEGORY_BITSTREAM_FILTER
        AV_CLASS_CATEGORY_SWSCALER
        AV_CLASS_CATEGORY_SWRESAMPLER
        AV_CLASS_CATEGORY_NB

    cdef struct AVClass:

        const char *class_name
        const char *(*item_name)(void*) nogil

        AVClassCategory category
        int parent_log_context_offset

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
        AV_LOG_MAX_OFFSET

    # Send a log.
    void av_log(void *ptr, int level, const char *fmt, ...)

    # Get the logs.
    ctypedef void(*av_log_callback)(void *, int, const char *, va_list)
    void av_log_default_callback(void *, int, const char *, va_list)
    void av_log_set_callback (av_log_callback callback)
    void av_log_set_level(int level)
