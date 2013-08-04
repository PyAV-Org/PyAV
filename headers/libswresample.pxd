cdef extern from "libswresample/swresample.h":

    cdef struct SwrContext:
        pass
        
    cdef void swr_free(SwrContext **s)