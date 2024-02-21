from collections.abc import MutableMapping

from av.error cimport err_check


cdef class _Dictionary:
    def __cinit__(self, *args, **kwargs):
        for arg in args:
            self.update(arg)
        if kwargs:
            self.update(kwargs)

    def __dealloc__(self):
        if self.ptr != NULL:
            lib.av_dict_free(&self.ptr)

    def __getitem__(self, str key):
        cdef lib.AVDictionaryEntry *element = lib.av_dict_get(self.ptr, key, NULL, 0)
        if element != NULL:
            return element.value
        else:
            raise KeyError(key)

    def __setitem__(self, str key, str value):
        err_check(lib.av_dict_set(&self.ptr, key, value, 0))

    def __delitem__(self, str key):
        err_check(lib.av_dict_set(&self.ptr, key, NULL, 0))

    def __len__(self):
        return err_check(lib.av_dict_count(self.ptr))

    def __iter__(self):
        cdef lib.AVDictionaryEntry *element = NULL
        while True:
            element = lib.av_dict_get(self.ptr, "", element, lib.AV_DICT_IGNORE_SUFFIX)
            if element == NULL:
                break
            yield element.key

    def __repr__(self):
        return f"av.Dictionary({dict(self)!r})"

    cpdef _Dictionary copy(self):
        cdef _Dictionary other = Dictionary()
        lib.av_dict_copy(&other.ptr, self.ptr, 0)
        return other


class Dictionary(_Dictionary, MutableMapping):
    pass


cdef _Dictionary wrap_dictionary(lib.AVDictionary *input_):
    cdef _Dictionary output = Dictionary()
    output.ptr = input_
    return output
