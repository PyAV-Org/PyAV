cimport libav as lib


cdef class Filter(object):

    cdef lib.AVFilter *ptr
    
    cdef readonly tuple inputs
    cdef readonly tuple outputs
    
    
cdef class FilterPad(object):
    
    cdef Filter filter
    cdef bint is_input
    cdef int index
    
    cdef lib.AVFilterPad *ptr
