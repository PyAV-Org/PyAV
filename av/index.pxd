cimport libav as lib

from av.stream cimport Stream


cdef class IndexEntry:
    cdef lib.AVIndexEntry entry
    cdef void _init(self, const lib.AVIndexEntry *ptr)

cdef class IndexEntries:
    cdef Stream stream
    cdef void _init(self, Stream stream)

cdef IndexEntries wrap_index_entries(Stream stream)
