cdef extern from "libavutil/bprint.h" nogil:
    
    cdef struct AVBPrint:

        char *str

    cdef int av_bprint_init(AVBPrint *buf, unsigned int init_size, unsigned int max_size)

    cdef int av_vbprintf(AVBPrint *buf, const char *fmt, va_list vl)

    cdef int av_bprint_finalize(AVBPrint *buf, char **optional_output)
