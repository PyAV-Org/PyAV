cdef extern from "libavutil/avutil.h":
    
    cdef int AV_ERROR_MAX_STRING_SIZE
    cdef int av_strerror(int errno, char *output, size_t output_size)

    cdef void* av_malloc(size_t size)
    cdef void av_free(void* ptr)
