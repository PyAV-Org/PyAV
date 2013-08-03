from libc.stdint cimport int64_t,uint8_t

cdef extern from "libavutil/avutil.h":

    cdef enum AVPixelFormat:
        AV_PIX_FMT_NONE
        AV_PIX_FMT_YUV420P
        AV_PIX_FMT_RGB24
        PIX_FMT_RGB24
        PIX_FMT_RGBA
        
    cdef enum AVSampleFormat:
        AV_SAMPLE_FMT_NONE
        AV_SAMPLE_FMT_S16
        AV_SAMPLE_FMT_FLTP
        
    cdef int AV_ERROR_MAX_STRING_SIZE
    
    cdef int AV_CH_LAYOUT_STEREO
    
    cdef double M_PI
    
    cdef int av_strerror(int errno, char *output, size_t output_size)
    cdef char* av_err2str(int errnum)

    cdef void* av_malloc(size_t size)
    cdef void av_free(void* ptr)
    
    cdef int av_get_bytes_per_sample(AVSampleFormat sample_fmt)
    
    cdef int av_samples_get_buffer_size(
        int *linesize,
        int nb_channels,
        int nb_samples,
        AVSampleFormat sample_fmt,
        int align
    )

    # See: http://ffmpeg.org/doxygen/trunk/structAVDictionary.html
    ctypedef struct AVDictionary:
        pass
    
    cdef void av_dict_free(AVDictionary **)
    
    # See: http://ffmpeg.org/doxygen/trunk/structAVDictionaryEntry.html
    ctypedef struct AVDictionaryEntry:
        char *key
        char *value
    
    cdef int AV_DICT_IGNORE_SUFFIX
    
    cdef AVDictionaryEntry* av_dict_get(
        AVDictionary *dict,
        char *key,
        AVDictionaryEntry *prev,
        int flags,
    )
    
    # See: http://ffmpeg.org/doxygen/trunk/structAVRational.html
    ctypedef struct AVRational:
        int num
        int den
        
    cdef AVRational AV_TIME_BASE_Q
    
    # Rescales from one time base to another
    cdef int64_t av_rescale_q(
        int64_t a, # time stamp
        AVRational bq, # source time base
        AVRational cq  # target time base
    )

cdef extern from "libavutil/pixdesc.h":
    cdef char * av_get_pix_fmt_name(AVPixelFormat pix_fmt)
    cdef AVPixelFormat av_get_pix_fmt(char* name)

    

