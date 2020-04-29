cimport libav as lib

from av.descriptor cimport wrap_avclass
from av.filter.pad cimport alloc_filter_pads


cdef object _cinit_sentinel = object()


cdef Filter wrap_filter(const lib.AVFilter *ptr):
    cdef Filter filter_ = Filter(_cinit_sentinel)
    filter_.ptr = ptr
    return filter_


cpdef enum FilterFlags:
    DYNAMIC_INPUTS = lib.AVFILTER_FLAG_DYNAMIC_INPUTS
    DYNAMIC_OUTPUTS = lib.AVFILTER_FLAG_DYNAMIC_OUTPUTS
    SLICE_THREADS = lib.AVFILTER_FLAG_SLICE_THREADS
    SUPPORT_TIMELINE_GENERIC = lib.AVFILTER_FLAG_SUPPORT_TIMELINE_GENERIC
    SUPPORT_TIMELINE_INTERNAL = lib.AVFILTER_FLAG_SUPPORT_TIMELINE_INTERNAL


cdef class Filter(object):

    def __cinit__(self, name):
        if name is _cinit_sentinel:
            return
        if not isinstance(name, str):
            raise TypeError('takes a filter name as a string')
        self.ptr = lib.avfilter_get_by_name(name)
        if not self.ptr:
            raise ValueError('no filter %s' % name)

    property descriptor:
        def __get__(self):
            if self._descriptor is None:
                self._descriptor = wrap_avclass(self.ptr.priv_class)
            return self._descriptor

    property options:
        def __get__(self):
            if self.descriptor is None:
                return
            return self.descriptor.options

    property name:
        def __get__(self):
            return self.ptr.name

    property description:
        def __get__(self):
            return self.ptr.description

    property flags:
        def __get__(self):
            return self.ptr.flags

    property dynamic_inputs:
        def __get__(self):
            return bool(self.ptr.flags & lib.AVFILTER_FLAG_DYNAMIC_INPUTS)

    property dynamic_outputs:
        def __get__(self):
            return bool(self.ptr.flags & lib.AVFILTER_FLAG_DYNAMIC_OUTPUTS)

    property timeline_support:
        def __get__(self):
            return bool(self.ptr.flags & lib.AVFILTER_FLAG_SUPPORT_TIMELINE_GENERIC)

    property slice_threads:
        def __get__(self):
            return bool(self.ptr.flags & lib.AVFILTER_FLAG_SLICE_THREADS)

    property command_support:
        def __get__(self):
            return self.ptr.process_command != NULL

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


cdef get_filter_names():
    names = set()
    cdef const lib.AVFilter *ptr
    cdef void *opaque = NULL
    while True:
        ptr = lib.av_filter_iterate(&opaque)
        if ptr:
            names.add(ptr.name)
        else:
            break
    return names

filters_available = get_filter_names()


filter_descriptor = wrap_avclass(lib.avfilter_get_class())
