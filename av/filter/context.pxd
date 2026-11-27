cimport libav as lib
from libc.stdbool cimport bool as c_bool

from av.filter.filter cimport Filter
from av.filter.graph cimport Graph


cdef class FilterContext:
    cdef lib.AVFilterContext *ptr
    cdef readonly Graph graph
    cdef readonly Filter filter
    cdef c_bool inited
    cdef unsigned char _kind


cdef FilterContext wrap_filter_context(Graph graph, Filter filter, lib.AVFilterContext *ptr)
