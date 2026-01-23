cdef extern from "libavdevice/avdevice.h" nogil:
    cdef int avdevice_version()
    cdef char* avdevice_configuration()
    cdef char* avdevice_license()
    void avdevice_register_all()
