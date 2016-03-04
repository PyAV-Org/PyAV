cimport libav as lib

from av.filter.context cimport FilterContext
from av.filter.filter cimport Filter


cdef class FilterPad(object):

    cdef Filter filter
    cdef FilterContext context
    cdef bint is_input
    cdef int index

    cdef lib.AVFilterPad *ptr


cdef class FilterContextPad(FilterPad):
    pass


cdef tuple alloc_filter_pads(Filter, lib.AVFilterPad *ptr, bint is_input, FilterContext context=?)
