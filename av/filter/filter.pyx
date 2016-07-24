cimport libav as lib

from av.filter.pad cimport alloc_filter_pads


cdef object _cinit_sentinel = object()


cdef Filter wrap_filter(lib.AVFilter *ptr):
    cdef Filter filter_ = Filter(_cinit_sentinel)
    filter_.ptr = ptr
    return filter_


cdef class Filter(object):

    def __cinit__(self, name):
        if name is _cinit_sentinel:
            return
        if not isinstance(name, basestring):
            raise TypeError('takes a filter name as a string')
        self.ptr = lib.avfilter_get_by_name(name)
        if not self.ptr:
            raise ValueError('no filter %s' % name)
    
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

    property inputs:
        def __get__(self):
            if self._inputs is None:
                self._inputs = alloc_filter_pads(self, self.ptr.inputs, True)
            return self._inputs
    
    property outputs:
        def __get__(self):
            if self._outputs is None:
                self._outputs = alloc_filter_pads(self, self.ptr.outputs, False)
            return self._outputs
