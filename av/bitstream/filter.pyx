cimport libav as lib

cdef extern from "filter-shims.c" nogil:
    cdef const lib.AVBitStreamFilter* pyav_filter_iterate(void **opaque)

from av.bitstream.context cimport BitStreamFilterContext


class UnknownFilterError(ValueError):
    pass


cdef object _cinit_sentinel = object()


cdef BitStreamFilter wrap_filter(const lib.AVBitStreamFilter *ptr):
    cdef BitStreamFilter filter_ = BitStreamFilter(_cinit_sentinel)
    filter_.ptr = ptr
    return filter_


cdef class BitStreamFilter(object):

    def __cinit__(self, name):

        if name is _cinit_sentinel:
            return

        self.ptr = lib.av_bsf_get_by_name(name)
        if not self.ptr:
            raise UnknownFilterError(name)

    @property
    def name(self):
        return self.ptr.name

    def create(self):
        return BitStreamFilterContext(self)


cdef get_filter_names():
    names = set()
    cdef const lib.AVBitStreamFilter *ptr
    cdef void *opaque = NULL
    while True:
        ptr = pyav_filter_iterate(&opaque)
        if ptr:
            names.add(ptr.name)
        else:
            break
    return names

bitstream_filters_availible = get_filter_names()
