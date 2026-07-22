cdef extern from "libswscale/swscale.h" nogil:
    cdef unsigned int swscale_version()
    cdef const char* swscale_configuration()
    cdef const char* swscale_license()

cdef extern from "libswresample/swresample.h" nogil:
    cdef unsigned int swresample_version()
    cdef const char* swresample_configuration()
    cdef const char* swresample_license()
