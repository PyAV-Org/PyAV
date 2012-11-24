

cdef extern from "libavutil/error.h":
    cdef int AV_ERROR_MAX_STRING_SIZE
    cdef int av_strerror(int errno, char *output, size_t output_size)


cdef extern from "libavcodec/avcodec.h":
    
    cdef enum AVCodecID:
        pass
    
    # See: http://ffmpeg.org/doxygen/trunk/structAVCodec.html
    cdef struct AVCodec:
        pass
    
    # See: http://ffmpeg.org/doxygen/trunk/structAVCodecContext.html
    cdef struct AVCodecContext:
        
        AVMediaType codec_type
        char codec_name[32]
        AVCodecID codec_id
        
    cdef AVCodec* avcodec_find_decoder(AVCodecID id)


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
    
    
cdef extern from "libswscale/swscale.h":
    pass
