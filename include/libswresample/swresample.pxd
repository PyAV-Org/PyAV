cdef extern from "libswresample/swresample.h" nogil:
    cdef int   swresample_version()
    cdef char* swresample_configuration()
    cdef char* swresample_license()
