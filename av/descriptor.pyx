cimport libav as lib

from .option cimport Option, wrap_option


cdef object _cinit_sentinel = object()

cdef Descriptor wrap_avclass(lib.AVClass *ptr):
    if ptr == NULL:
        return None
    cdef Descriptor obj = Descriptor(_cinit_sentinel)
    obj.ptr = ptr
    return obj


cdef class Descriptor(object):

    def __cinit__(self, sentinel):
        if sentinel is not _cinit_sentinel:
            raise RuntimeError('Cannot construct av.Descriptor')

    property name:
        def __get__(self): return self.ptr.class_name if self.ptr.class_name else None

    property options:
        def __get__(self):
            cdef lib.AVOption *ptr
            cdef Option option
            if self._options is None:
                options = []
                ptr = self.ptr.option
                while ptr != NULL and ptr.name != NULL:
                    option = wrap_option(ptr)
                    options.append(option)
                    ptr += 1
                self._options = tuple(options)
            return self._options

    def __repr__(self):
        return '<%s %s at 0x%x>' % (self.__class__.__name__, self.name, id(self))
