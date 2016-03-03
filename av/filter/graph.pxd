cimport libav as lib


cdef class Graph(object):

    cdef lib.AVFilterGraph *ptr
    
    cdef readonly bint configured
    cpdef configure(self, bint force=*)
    
    cdef dict name_counts
    cdef str get_unique_name(self, str name)
    