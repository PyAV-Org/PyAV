from collections.abc import MutableMapping

import cython
from cython.cimports.av.error import err_check


@cython.cclass
class _Dictionary:
    def __cinit__(self, *args, **kwargs):
        for arg in args:
            self.update(arg)
        if kwargs:
            self.update(kwargs)

    def __dealloc__(self):
        if self.ptr != cython.NULL:
            lib.av_dict_free(cython.address(self.ptr))

    def __getitem__(self, key: cython.str):
        element = cython.declare(
            cython.pointer[lib.AVDictionaryEntry],
            lib.av_dict_get(self.ptr, key, cython.NULL, 0),
        )
        if element == cython.NULL:
            raise KeyError(key)
        return element.value

    def __setitem__(self, key: cython.str, value: cython.str):
        err_check(lib.av_dict_set(cython.address(self.ptr), key, value, 0))

    def __delitem__(self, key: cython.str):
        err_check(lib.av_dict_set(cython.address(self.ptr), key, cython.NULL, 0))

    def __len__(self):
        return err_check(lib.av_dict_count(self.ptr))

    def __iter__(self):
        element = cython.declare(cython.pointer[lib.AVDictionaryEntry], cython.NULL)
        while True:
            element = lib.av_dict_get(self.ptr, "", element, lib.AV_DICT_IGNORE_SUFFIX)
            if element == cython.NULL:
                break
            yield element.key

    def __repr__(self):
        return f"av.Dictionary({dict(self)!r})"

    def copy(self):
        other = cython.declare(_Dictionary, Dictionary())
        lib.av_dict_copy(cython.address(other.ptr), self.ptr, 0)
        return other


class Dictionary(_Dictionary, MutableMapping):
    pass


@cython.cfunc
def wrap_dictionary(input_: cython.pointer[lib.AVDictionary]) -> _Dictionary:
    output = cython.declare(_Dictionary, Dictionary())
    output.ptr = input_
    return output
