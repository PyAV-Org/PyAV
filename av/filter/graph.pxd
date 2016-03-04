cimport libav as lib


cdef class Graph(object):

    cdef lib.AVFilterGraph *ptr
    
    cdef readonly bint configured
    cpdef configure(self, bint force=*)
    
    cdef dict _name_counts
    cdef str _get_unique_name(self, str name)
    
    cdef dict _context_by_ptr
    cdef dict _context_by_name
    