cimport libav as lib

from av.filter.context cimport FilterContext
from av.filter.filter cimport Filter
from av.filter.graph cimport Graph


cdef class FilterLink:
    cdef readonly Graph graph
    cdef lib.AVFilterLink *ptr


cdef FilterLink wrap_filter_link(Graph graph, lib.AVFilterLink *ptr)

cdef class FilterPad:
    cdef readonly Filter filter
    cdef readonly FilterContext context
    cdef const lib.AVFilterPad *base_ptr
    cdef readonly bint is_input
    cdef readonly int index


cdef class FilterContextPad(FilterPad):
    cdef FilterLink _link


cdef tuple[FilterPad, ...] alloc_filter_pads(Filter, const lib.AVFilterPad *ptr, bint is_input, FilterContext context=?)
