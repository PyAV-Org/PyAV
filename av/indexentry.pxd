cimport libav as lib

cdef class IndexEntry:

    cdef lib.AVIndexEntry *ptr
    cdef _init(self, lib.AVIndexEntry *ptr)


cdef IndexEntry wrap_index_entry(lib.AVIndexEntry *ptr)