cimport libav as lib


cdef class AVRational:
    cdef readonly int num
    cdef readonly int den

    cdef lib.AVRational _q(self)


cdef AVRational from_avrational(lib.AVRational q)
