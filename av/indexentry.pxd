cimport libav as lib

cdef class IndexEntry:

    cdef lib.AVIndexEntry *ptr
    cdef _init(self, lib.AVIndexEntry *ptr)