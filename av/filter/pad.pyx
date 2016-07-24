from av.utils cimport media_type_to_string
from av.filter.link cimport wrap_filter_link


cdef object _cinit_sentinel = object()


cdef class FilterPad(object):
    
    def __cinit__(self, sentinel):
        if sentinel is not _cinit_sentinel:
            raise RuntimeError('cannot construct FilterPad')
    
    def __repr__(self):
        return '<av.FilterPad %s.%s[%d]: %s (%s)>' % (
            self.filter.name,
            'inputs' if self.is_input else 'outputs',
            self.index,
            self.name,
            self.type,
        )

    property is_output:
        def __get__(self):
            return not self.is_input

    property name:
        def __get__(self):
            return lib.avfilter_pad_get_name(self.base_ptr, self.index)
    
    property type:
        def __get__(self):
            return media_type_to_string(lib.avfilter_pad_get_type(self.base_ptr, self.index))


cdef class FilterContextPad(FilterPad):
    
    def __repr__(self):
        
        return '<av.FilterContextPad %s.%s[%d] of %s: %s (%s)>' % (
            self.filter.name,
            'inputs' if self.is_input else 'outputs',
            self.index,
            self.context.name,
            self.name,
            self.type,
        )
    
    property link:
        def __get__(self):
            if self._link:
                return self._link
            cdef lib.AVFilterLink **links = self.context.ptr.inputs if self.is_input else self.context.ptr.outputs
            cdef lib.AVFilterLink *link = links[self.index]
            if not link:
                return
            self._link = wrap_filter_link(self.context.graph, link)
            return self._link

    property linked:
        def __get__(self):
            cdef FilterLink link = self.link
            if link:
                return link.input if self.is_input else link.output


cdef tuple alloc_filter_pads(Filter filter, lib.AVFilterPad *ptr, bint is_input, FilterContext context=None):
    
    if not ptr:
        return ()
    
    pads = []
    
    # We need to be careful and check our bounds if we know what they are,
    # since the arrays on a AVFilterContext are not NULL terminated.
    cdef int i = 0
    cdef int count = (context.ptr.nb_inputs if is_input else context.ptr.nb_outputs) if context is not None else -1

    cdef FilterPad pad
    while (i < count or count < 0) and lib.avfilter_pad_get_name(ptr, i):
        pad = FilterPad(_cinit_sentinel) if context is None else FilterContextPad(_cinit_sentinel)
        pads.append(pad)
        pad.filter = filter
        pad.context = context
        pad.is_input = is_input
        pad.base_ptr = ptr
        pad.index = i
        i += 1
    
    return tuple(pads)
