from av.utils cimport media_type_to_string
cimport libav as lib


cdef class FilterPad(object):
    
    def __cinit__(self, Filter filter, bint is_input, int index):
        
        self.filter = filter
        self.is_input = is_input
        self.index = index
        
        cdef lib.AVFilterPad *pads = filter.ptr.inputs if is_input else filter.ptr.outputs
        if not pads:
            raise ValueError('no %s pads' % ('input' if is_input else 'output'))
        
        cdef int i = 0
        while i <= index:
            if not pads[i].name:
                raise ValueError('no %s pad %d' % ('input' if is_input else 'output', index))
            i += 1
        
        self.ptr = &pads[index]
    
    def __repr__(self):
        return '<av.FilterPad %s[%d]: %s (%s)>' % (self.filter.name, self.index, self.name, self.type)

    property name:
        def __get__(self):
            return self.ptr.name
    
    property type:
        def __get__(self):
            return media_type_to_string(self.ptr.type)


cdef get_pads(Filter filter, bint is_input):
    cdef int i = 0
    pads = []
    while True:
        try:
            pads.append(FilterPad(filter, is_input, i))
        except ValueError:
            break
        else:
            i += 1
    return pads


cdef class Filter(object):

    def __cinit__(self, name):
        
        if isinstance(name, basestring):
            self.ptr = lib.avfilter_get_by_name(name)
            if not self.ptr:
                raise ValueError('no filter %s' % name)
        else:
            raise TypeError('takes a filter name as a string')
            
        self.inputs = tuple(get_pads(self, True))
        self.outputs = tuple(get_pads(self, False))
    
    property name:
        def __get__(self):
            return self.ptr.name
    
    property description:
        def __get__(self):
            return self.ptr.description
    
    property dynamic_inputs:
        def __get__(self):
            return bool(self.ptr.flags & lib.AVFILTER_FLAG_DYNAMIC_INPUTS)
            
    property dynamic_outputs:
        def __get__(self):
            return bool(self.ptr.flags & lib.AVFILTER_FLAG_DYNAMIC_OUTPUTS)