from libc.stdint cimport int64_t, uint64_t

cdef extern from "libavformat_compat.h" nogil:
    
    cdef int AV_TIME_BASE
    cdef int AVSEEK_FLAG_BACKWARD
    cdef int AVSEEK_FLAG_BYTE 
    cdef int AVSEEK_FLAG_ANY 
    cdef int AVSEEK_FLAG_FRAME
    

    cdef int AVIO_FLAG_WRITE
    
    # Initialize libavformat.
    cdef void av_register_all()
    
    cdef enum AVMediaType:
        AVMEDIA_TYPE_UNKNOWN
        AVMEDIA_TYPE_VIDEO
        AVMEDIA_TYPE_AUDIO
        AVMEDIA_TYPE_DATA
        AVMEDIA_TYPE_SUBTITLE
        AVMEDIA_TYPE_ATTACHMENT
        AVMEDIA_TYPE_NB
    
    # See: http://ffmpeg.org/doxygen/trunk/structAVFrac.html
    cdef struct AVFrac:
        int64_t val
        int64_t num
        int64_t den
    
    # See: http://ffmpeg.org/doxygen/trunk/structAVStream.html
    cdef struct AVStream:
        
        int index
        int id
        
        AVCodecContext *codec
        
        AVFrac pts
        AVRational r_frame_rate
        AVRational time_base
        
        int64_t start_time
        int64_t duration
        int64_t nb_frames
        int64_t cur_dts
        
        AVDictionary *metadata
        
        AVRational avg_frame_rate
    
    # http://ffmpeg.org/doxygen/trunk/structAVIOContext.html
    cdef struct AVIOContext:
        int write_flag
        
    # http://ffmpeg.org/doxygen/trunk/structAVInputFormat.html
    cdef struct AVInputFormat:
        const char *name
        const char *long_name
        const char *extensions
        int flags
        # const AVCodecTag* const *codec_tag
        # const AVClass *priv_class
    
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
        # const AVClass *priv_class

    cdef int AVFMT_NOFILE
    cdef int AVFMT_NEEDNUMBER
    cdef int AVFMT_RAWPICTURE
    cdef int AVFMT_GLOBALHEADER
    cdef int AVFMT_NOTIMESTAMPS
    cdef int AVFMT_VARIABLE_FPS
    cdef int AVFMT_NODIMENSIONS
    cdef int AVFMT_NOSTREAMS
    cdef int AVFMT_ALLOW_FLUSH
    cdef int AVFMT_TS_NONSTRICT

    cdef AVInputFormat* av_find_input_format(const char *name)
    cdef AVInputFormat* av_iformat_next(AVInputFormat*)
    cdef AVOutputFormat* av_oformat_next(AVOutputFormat*)
    
    # http://ffmpeg.org/doxygen/trunk/structAVFormatContext.html
    cdef struct AVFormatContext:
        
        # Streams.
        unsigned int nb_streams
        AVStream **streams
        
        AVInputFormat *iformat
        AVOutputFormat *oformat
        
        AVIOContext *pb
        
        AVDictionary *metadata
        
        char filename
        int64_t start_time
        int64_t duration
        int bit_rate
        
        int flags
    
    cdef int avformat_open_input(
        AVFormatContext **ctx, # NULL will allocate for you.
        char *filename,
        AVInputFormat *format, # Can be NULL.
        AVDictionary **options # Can be NULL.
    )
    
    cdef int avformat_close_input(AVFormatContext **ctx)
    
    cdef int avformat_write_header(
        AVFormatContext *ctx,
        AVDictionary **options # Can be NULL
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
         
    cdef int avio_close(AVIOContext *s)
    
    cdef int avio_closep(AVIOContext **s)
    
    cdef int avformat_find_stream_info(
        AVFormatContext *ctx,
        AVDictionary **options, # Can be NULL.
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
    

    
