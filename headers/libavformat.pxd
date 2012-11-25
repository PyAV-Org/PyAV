cdef extern from "libavformat/avformat.h":
    
    # Initialize libavformat.
    cdef void av_register_all()
    
    cdef enum AVMediaType:
        AVMEDIA_TYPE_VIDEO
        AVMEDIA_TYPE_AUDIO
        # There are a few more...
        
    # See: http://ffmpeg.org/doxygen/trunk/structAVStream.html
    cdef struct AVStream:
        
        AVCodecContext *codec
    
    # http://ffmpeg.org/doxygen/trunk/structAVFormatContext.html
    cdef struct AVFormatContext:
        
        # Streams.
        unsigned int nb_streams
        AVStream **streams
    
    
    # http://ffmpeg.org/doxygen/trunk/structAVInputFormat.html
    cdef struct AVInputFormat:
        pass
        
    # http://ffmpeg.org/doxygen/trunk/structAVDictionary.html
    cdef struct AVDictionary:
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