from libc.stdint cimport int64_t, uint64_t


cdef extern from "libavformat/avformat.h":
    
    cdef int AV_TIME_BASE
    
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
        # There are a few more...
    
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
        
        AVRational r_frame_rate
        AVRational time_base
        
        int64_t start_time
        int64_t duration
        int64_t nb_frames
        
        AVDictionary *metadata
        
        AVRational avg_frame_rate
        
    
    # http://ffmpeg.org/doxygen/trunk/structAVFormatContext.html
    cdef struct AVFormatContext:
        
        # Streams.
        unsigned int nb_streams
        AVStream **streams
        
        AVDictionary *metadata
        
        int64_t start_time
        int64_t duration
        int bit_rate
        
    
    # http://ffmpeg.org/doxygen/trunk/structAVInputFormat.html
    cdef struct AVInputFormat:
        pass
    
    # Once called av_open_input_file, but no longer.
    cdef int avformat_open_input(
        AVFormatContext **ctx, # NULL will allocate for you.
        char *filename,
        AVInputFormat *format, # Can be NULL.
        AVDictionary **options # Can be NULL.
    )
    
    cdef int avformat_close_input(AVFormatContext **ctx)
    
    cdef int avformat_find_stream_info(
        AVFormatContext *ctx,
        AVDictionary **options, # Can be NULL.
    )
    
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