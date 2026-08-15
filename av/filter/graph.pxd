cimport libav as lib

from av.filter.context cimport FilterContext


cdef class Graph:
    # Fields are laid out in declaration order: pointers first, then the two
    # ints paired up, so there are no padding holes between them.
    cdef object __weakref__
    cdef lib.AVFilterGraph *ptr
    cdef dict _name_counts
    cdef dict[size_t, FilterContext] _context_by_ptr
    cdef dict[str, list[FilterContext]] _context_by_type
    cdef readonly bint configured
    cdef int _nb_filters_seen

    cpdef configure(self, bint auto_buffer=*, bint force=*)
    cdef str _get_unique_name(self, str name)
    cdef list[FilterContext] _get_context_by_type(self, str type)
    cdef void _register_context(self, FilterContext)
    cdef void _auto_register(self)
