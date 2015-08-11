cimport libav as lib


cdef class Descriptor(object):

    cdef lib.AVClass *ptr
    
    cdef object _options # Option list cache.


cdef Descriptor wrap_avclass(lib.AVClass*)
