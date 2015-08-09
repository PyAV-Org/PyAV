cimport libav as lib


cdef class Class(object):

    cdef lib.AVClass *ptr
    cdef object _options # Option list cache.


cdef Class wrap_class(lib.AVClass*)
