cdef extern from "libswscale/swscale.h" nogil:
    cdef int swscale_version()
    cdef char* swscale_configuration()
    cdef char* swscale_license()

cdef extern from "libswresample/swresample.h" nogil:
    cdef int swresample_version()
    cdef char* swresample_configuration()
    cdef char* swresample_license()
