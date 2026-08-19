cimport libav as lib


cdef class Filter:
    cdef const lib.AVFilter *ptr
    cdef tuple _inputs
    cdef tuple _outputs


cdef Filter wrap_filter(const lib.AVFilter *ptr)
