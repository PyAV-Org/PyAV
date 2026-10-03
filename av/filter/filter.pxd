cimport libav as lib


cdef class Filter:
    cdef const lib.AVFilter *ptr


cdef Filter wrap_filter(const lib.AVFilter *ptr)
