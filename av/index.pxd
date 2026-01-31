cimport libav as lib


cdef class IndexEntry:
    cdef lib.AVIndexEntry *ptr
    cdef _init(self, lib.AVIndexEntry *ptr)

cdef class IndexEntries:
    cdef lib.AVStream *stream_ptr
    cdef _init(self, lib.AVStream *ptr)

cdef IndexEntries wrap_index_entries(lib.AVStream *ptr)
