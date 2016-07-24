cimport libav as lib


cdef class Filter(object):

    cdef lib.AVFilter *ptr
    
    cdef object _inputs
    cdef object _outputs
    
    
cdef Filter wrap_filter(lib.AVFilter *ptr)
