from libc.stdint cimport int64_t

cdef extern from "libavutil/avutil.h":
    
    cdef int AV_ERROR_MAX_STRING_SIZE
    cdef int av_strerror(int errno, char *output, size_t output_size)

    cdef void* av_malloc(size_t size)
    cdef void av_free(void* ptr)

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
    

