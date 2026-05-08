cimport libav as lib


cdef class Filter:
    cdef const lib.AVFilter *ptr
    cdef object _inputs
    cdef object _outputs


cdef Filter wrap_filter(const lib.AVFilter *ptr)
