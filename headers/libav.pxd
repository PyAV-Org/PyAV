

cdef extern from "Python.h":
    
    cdef object PyBuffer_FromMemory(void *ptr, size_t size)
    
    
cdef extern from "libavutil/avutil.h":
    cdef int AV_ERROR_MAX_STRING_SIZE
    cdef int av_strerror(int errno, char *output, size_t output_size)

    cdef void* av_malloc(size_t size)
    cdef void av_free(void* ptr)


cdef extern from "libavcodec/avcodec.h":
    
    cdef enum AVCodecID:
        pass
    
    # See: http://ffmpeg.org/doxygen/trunk/structAVCodec.html
    cdef struct AVCodec:
        char *name
        char *long_name
    
    cdef enum AVPixelFormat:
        PIX_FMT_RGB24
        PIX_FMT_RGBA
            
    # See: http://ffmpeg.org/doxygen/trunk/structAVCodecContext.html
    cdef struct AVCodecContext:
        
        AVMediaType codec_type
        char codec_name[32]
        AVCodecID codec_id
        
        int width
        int height
        
        AVPixelFormat pix_fmt
        
        
    cdef AVCodec* avcodec_find_decoder(AVCodecID id)
    
    cdef int avcodec_open2(
        AVCodecContext *ctx,
        AVCodec *codec,
        AVDictionary **options,
    )
    cdef int avcodec_close(AVCodecContext *ctx)
    
    cdef struct AVPicture:
        pass
    
    # See: http://ffmpeg.org/doxygen/trunk/structAVFrame.html
    # This is a strict superset of AVPicture.
    cdef struct AVFrame:
        unsigned char **data
        int *linesize
        unsigned char **extended_data
        int width
        int height
        int nb_samples
        int format
        int key_frame # 0 or 1.
        
        unsigned char *base

    cdef AVFrame* avcodec_alloc_frame()
    
    cdef int avpicture_get_size(
        AVPixelFormat format,
        int width,
        int height,
    )
    
    cdef int avpicture_fill(
        AVPicture *picture,
        unsigned char *buffer,
        AVPixelFormat format,
        int width,
        int height
    )
    
    cdef struct AVPacket:
        int stream_index
    
    cdef int avcodec_decode_video2(
        AVCodecContext *ctx,
        AVFrame *picture,
        int *got_picture,
        AVPacket *packet,
    )
    
    cdef void av_free_packet(AVPacket*)
    

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
    
    cdef int av_close_input_file(AVFormatContext *ctx)
    
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
    
    
cdef extern from "libswscale/swscale.h":
    
    # See: http://ffmpeg.org/doxygen/trunk/structSwsContext.html
    cdef struct SwsContext:
        pass
    
    # See: http://ffmpeg.org/doxygen/trunk/structSwsFilter.html
    cdef struct SwsFilter:
        pass
    
    # Flags.
    cdef int SWS_BILINEAR
    
    cdef SwsContext* sws_getContext(
        int src_width,
        int src_height,
        AVPixelFormat src_format,
        int dst_width,
        int dst_height,
        AVPixelFormat dst_format,
        int flags,
        SwsFilter *src_filter,
        SwsFilter *dst_filter,
        double *param,
    )
    
    cdef int sws_scale(
        SwsContext *ctx,
        unsigned char **src_slice,
        int *src_stride,
        int src_slice_y,
        int src_slice_h,
        unsigned char **dst_slice,
        int *dst_stride,
    )
