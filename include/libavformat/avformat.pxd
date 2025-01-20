from libc.stdint cimport int64_t, uint64_t


cdef extern from "libavformat/avformat.h" nogil:

    cdef int   avformat_version()
    cdef char* avformat_configuration()
    cdef char* avformat_license()
    cdef void  avformat_network_init()

    cdef int64_t INT64_MIN

    cdef int AV_TIME_BASE
    cdef int AVSEEK_FLAG_BACKWARD
    cdef int AVSEEK_FLAG_BYTE
    cdef int AVSEEK_FLAG_ANY
    cdef int AVSEEK_FLAG_FRAME

    cdef int AVIO_FLAG_WRITE

    cdef enum AVMediaType:
        AVMEDIA_TYPE_UNKNOWN
        AVMEDIA_TYPE_VIDEO
        AVMEDIA_TYPE_AUDIO
        AVMEDIA_TYPE_DATA
        AVMEDIA_TYPE_SUBTITLE
        AVMEDIA_TYPE_ATTACHMENT
        AVMEDIA_TYPE_NB

    cdef struct AVStream:
        int index
        int id
        int disposition

        AVCodecParameters *codecpar
        AVRational time_base

        int64_t start_time
        int64_t duration
        int64_t nb_frames
        int64_t cur_dts
        AVDictionary *metadata
        AVRational avg_frame_rate
        AVRational r_frame_rate
        AVRational sample_aspect_ratio

    # http://ffmpeg.org/doxygen/trunk/structAVIOContext.html
    cdef struct AVIOContext:
        unsigned char* buffer
        int buffer_size
        int write_flag
        int direct
        int seekable
        int max_packet_size
        void *opaque

    # http://ffmpeg.org/doxygen/trunk/structAVIOInterruptCB.html
    cdef struct AVIOInterruptCB:
        int (*callback)(void*)
        void *opaque

    cdef int AVIO_FLAG_DIRECT
    cdef int AVIO_SEEKABLE_NORMAL

    cdef int SEEK_SET
    cdef int SEEK_CUR
    cdef int SEEK_END
    cdef int AVSEEK_SIZE

    cdef AVIOContext* avio_alloc_context(
        unsigned char *buffer,
        int buffer_size,
        int write_flag,
        void *opaque,
        int(*read_packet)(void *opaque, uint8_t *buf, int buf_size),
        int(*write_packet)(void *opaque, const uint8_t *buf, int buf_size),
        int64_t(*seek)(void *opaque, int64_t offset, int whence)
    )

    # http://ffmpeg.org/doxygen/trunk/structAVInputFormat.html
    cdef struct AVInputFormat:
        const char *name
        const char *long_name
        const char *extensions
        int flags
        # const AVCodecTag* const *codec_tag
        const AVClass *priv_class

    cdef struct AVProbeData:
        unsigned char *buf
        int buf_size
        const char *filename

    cdef AVInputFormat* av_probe_input_format(
        AVProbeData *pd,
        int is_opened
    )

    # http://ffmpeg.org/doxygen/trunk/structAVOutputFormat.html
    cdef struct AVOutputFormat:
        const char *name
        const char *long_name
        const char *extensions
        AVCodecID video_codec
        AVCodecID audio_codec
        AVCodecID subtitle_codec
        int flags
        # const AVCodecTag* const *codec_tag
        const AVClass *priv_class

    int avformat_query_codec(const AVOutputFormat *oformat, AVCodecID codec_id, int std_compliance)

    # AVInputFormat.flags and AVOutputFormat.flags
    cdef enum:
        AVFMT_NOFILE
        AVFMT_NEEDNUMBER
        AVFMT_SHOW_IDS
        AVFMT_GLOBALHEADER
        AVFMT_NOTIMESTAMPS
        AVFMT_GENERIC_INDEX
        AVFMT_TS_DISCONT
        AVFMT_VARIABLE_FPS
        AVFMT_NODIMENSIONS
        AVFMT_NOSTREAMS
        AVFMT_NOBINSEARCH
        AVFMT_NOGENSEARCH
        AVFMT_NO_BYTE_SEEK
        AVFMT_ALLOW_FLUSH
        AVFMT_TS_NONSTRICT
        AVFMT_TS_NEGATIVE
        AVFMT_SEEK_TO_PTS

    # AVFormatContext.flags
    cdef enum:
        AVFMT_FLAG_GENPTS
        AVFMT_FLAG_IGNIDX
        AVFMT_FLAG_NONBLOCK
        AVFMT_FLAG_IGNDTS
        AVFMT_FLAG_NOFILLIN
        AVFMT_FLAG_NOPARSE
        AVFMT_FLAG_NOBUFFER
        AVFMT_FLAG_CUSTOM_IO
        AVFMT_FLAG_DISCARD_CORRUPT
        AVFMT_FLAG_FLUSH_PACKETS
        AVFMT_FLAG_BITEXACT
        AVFMT_FLAG_SORT_DTS
        AVFMT_FLAG_FAST_SEEK
        AVFMT_FLAG_SHORTEST
        AVFMT_FLAG_AUTO_BSF

    cdef int av_probe_input_buffer(
        AVIOContext *pb,
        AVInputFormat **fmt,
        const char *filename,
        void *logctx,
        unsigned int offset,
        unsigned int max_probe_size
    )

    cdef int av_find_best_stream(
        AVFormatContext *ic,
        AVMediaType type,
        int wanted_stream_nb,
        int related_stream,
        AVCodec **decoder_ret,
        int flags
    ) 

    cdef AVInputFormat* av_find_input_format(const char *name)

    # http://ffmpeg.org/doxygen/trunk/structAVFormatContext.html
    cdef struct AVFormatContext:

        # Streams.
        unsigned int nb_streams
        AVStream **streams

        AVInputFormat *iformat
        AVOutputFormat *oformat

        AVIOContext *pb
        AVIOInterruptCB interrupt_callback

        AVDictionary *metadata

        char filename
        int64_t start_time
        int64_t duration
        int bit_rate

        int flags
        int64_t max_analyze_duration

        void *opaque

        int (*io_open)(
            AVFormatContext *s,
            AVIOContext **pb,
            const char *url,
            int flags,
            AVDictionary **options
        )
        int (*io_close2)(
            AVFormatContext *s,
            AVIOContext *pb
        )

    cdef AVFormatContext* avformat_alloc_context()

    # .. c:function:: avformat_open_input(...)
    #
    #       Options are passed via :func:`av.open`.
    #
    #       .. seealso:: FFmpeg's docs: :ffmpeg:`avformat_open_input`
    #
    cdef int avformat_open_input(
        AVFormatContext **ctx,  # NULL will allocate for you.
        char *filename,
        AVInputFormat *format,  # Can be NULL.
        AVDictionary **options  # Can be NULL.
    )

    cdef int avformat_close_input(AVFormatContext **ctx)

    # .. c:function:: avformat_write_header(...)
    #
    #       Options are passed via :func:`av.open`; called in
    #       :meth:`av.container.OutputContainer.start_encoding`.
    #
    #       .. seealso:: FFmpeg's docs: :ffmpeg:`avformat_write_header`
    #
    cdef int avformat_write_header(
        AVFormatContext *ctx,
        AVDictionary **options  # Can be NULL
    )

    cdef int av_write_trailer(AVFormatContext *ctx)

    cdef int av_interleaved_write_frame(
        AVFormatContext *ctx,
        AVPacket *pkt
    )

    cdef int av_write_frame(
        AVFormatContext *ctx,
        AVPacket *pkt
    )

    cdef int avio_open(
        AVIOContext **s,
        char *url,
        int flags
    )

    cdef int64_t avio_size(
        AVIOContext *s
    )

    cdef AVOutputFormat* av_guess_format(
        char *short_name,
        char *filename,
        char *mime_type
    )

    cdef int avformat_query_codec(
        AVOutputFormat *ofmt,
        AVCodecID codec_id,
        int std_compliance
    )

    cdef void avio_flush(AVIOContext *s)

    cdef int avio_close(AVIOContext *s)

    cdef int avio_closep(AVIOContext **s)

    cdef int avformat_find_stream_info(
        AVFormatContext *ctx,
        AVDictionary **options,  # Can be NULL.
    )

    cdef AVStream* avformat_new_stream(
        AVFormatContext *ctx,
        AVCodec *c
    )

    cdef int avformat_alloc_output_context2(
        AVFormatContext **ctx,
        AVOutputFormat *oformat,
        char *format_name,
        char *filename
    )

    cdef int avformat_free_context(AVFormatContext *ctx)

    cdef AVClass* avformat_get_class()

    cdef void av_dump_format(
        AVFormatContext *ctx,
        int index,
        char *url,
        int is_output,
    )

    cdef int av_read_frame(
        AVFormatContext *ctx,
        AVPacket *packet,
    )

    cdef int av_seek_frame(
        AVFormatContext *ctx,
        int stream_index,
        int64_t timestamp,
        int flags
    )

    cdef int avformat_seek_file(
        AVFormatContext *ctx,
        int stream_index,
        int64_t min_ts,
        int64_t ts,
        int64_t max_ts,
        int flags
    )

    cdef AVRational av_guess_frame_rate(
        AVFormatContext *ctx,
        AVStream *stream,
        AVFrame *frame
    )

    cdef AVRational av_guess_sample_aspect_ratio(
        AVFormatContext *ctx,
        AVStream *stream,
        AVFrame *frame
    )

    cdef const AVInputFormat* av_demuxer_iterate(void **opaque)
    cdef const AVOutputFormat* av_muxer_iterate(void **opaque)

    # custom

    cdef set pyav_get_available_formats()
