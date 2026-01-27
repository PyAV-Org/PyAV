import cython
from cython.cimports import libav as lib
from cython.cimports.av.descriptor import wrap_avclass
from cython.cimports.av.filter.link import alloc_filter_pads

_cinit_sentinel = cython.declare(object, object())


@cython.cfunc
def wrap_filter(ptr: cython.pointer[cython.const[lib.AVFilter]]) -> Filter:
    filter_: Filter = Filter(_cinit_sentinel)
    filter_.ptr = ptr
    return filter_


@cython.cclass
class Filter:
    def __cinit__(self, name):
        if name is _cinit_sentinel:
            return
        if not isinstance(name, str):
            raise TypeError("takes a filter name as a string")

        self.ptr = lib.avfilter_get_by_name(name)
        if not self.ptr:
            raise ValueError(f"no filter {name}")

    @property
    def descriptor(self):
        if self._descriptor is None:
            self._descriptor = wrap_avclass(self.ptr.priv_class)
        return self._descriptor

    @property
    def options(self):
        if self.descriptor is None:
            return
        return self.descriptor.options

    @property
    def name(self):
        return self.ptr.name

    @property
    def description(self):
        return self.ptr.description

    @property
    def flags(self):
        return self.ptr.flags

    @property
    def inputs(self):
        if self._inputs is None:
            self._inputs = alloc_filter_pads(self, self.ptr.inputs, True)
        return self._inputs

    @property
    def outputs(self):
        if self._outputs is None:
            self._outputs = alloc_filter_pads(self, self.ptr.outputs, False)
        return self._outputs


@cython.cfunc
def get_filter_names() -> set:
    names: set = set()
    ptr: cython.pointer[cython.const[lib.AVFilter]]
    opaque: cython.p_void = cython.NULL
    while True:
        ptr = lib.av_filter_iterate(cython.address(opaque))
        if ptr:
            names.add(ptr.name)
        else:
            break
    return names


filters_available = get_filter_names()
filter_descriptor = wrap_avclass(lib.avfilter_get_class())
