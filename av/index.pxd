cimport libav as lib


cdef class IndexEntry:
    cdef const lib.AVIndexEntry *ptr
    cdef _init(self, const lib.AVIndexEntry *ptr)

cdef class IndexEntries:
    cdef lib.AVStream *stream_ptr
    cdef _init(self, lib.AVStream *ptr)

cdef IndexEntries wrap_index_entries(lib.AVStream *ptr)
