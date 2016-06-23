cimport libav as lib

from av.filter.context cimport FilterContext
from av.filter.filter cimport Filter
from av.filter.link cimport FilterLink


cdef class FilterPad(object):

    cdef Filter filter
    cdef FilterContext context
    cdef bint is_input
    cdef int index

    cdef lib.AVFilterPad *base_ptr


cdef class FilterContextPad(FilterPad):

    cdef FilterLink _link


cdef tuple alloc_filter_pads(Filter, lib.AVFilterPad *ptr, bint is_input, FilterContext context=?)
