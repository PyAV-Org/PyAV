from av.utils cimport media_type_to_string


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

    property name:
        def __get__(self):
            return self.ptr.name
    
    property type:
        def __get__(self):
            return media_type_to_string(self.ptr.type)


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
    
    property linked_to:
        def __get__(self):
            
            cdef lib.AVFilterLink **links = self.context.ptr.inputs if self.is_input else self.context.ptr.outputs
            cdef lib.AVFilterLink *link = links[self.index]
            if not link:
                return
            
            # Get the "other" context.
            cdef lib.AVFilterContext *c_context
            if self.is_input:
                c_context = link.src
            else:
                c_context = link.dst
            cdef FilterContext context = self.context.graph._context_by_ptr[<long>c_context]
            
            # Get the "other" pad.
            cdef lib.AVFilterPad *c_pad
            if self.is_input:
                c_pad = link.srcpad
                pads = context.outputs
            else:
                c_pad = link.dstpad
                pads = context.inputs
            
            # We need to find it by looking, because there is no
            cdef FilterPad pad
            for pad in pads:
                if pad.ptr == c_pad:
                    return pad
            raise RuntimeError('could not find matching pad')


cdef tuple alloc_filter_pads(Filter filter, lib.AVFilterPad *ptr, bint is_input, FilterContext context=None):
    
    if not ptr:
        return ()
    
    pads = []
    
    cdef int i = 0
    cdef FilterPad pad
    while ptr[i].name:
        pad = FilterPad(_cinit_sentinel) if context is None else FilterContextPad(_cinit_sentinel)
        pads.append(pad)
        pad.filter = filter
        pad.context = context
        pad.is_input = is_input
        pad.index = i
        pad.ptr = &ptr[i]
        i += 1
    
    return tuple(pads)
