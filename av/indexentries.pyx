from cython.cimports import libav as lib
from typing import Iterator
from libc.stdint cimport int64_t

from av.indexentry cimport IndexEntry, wrap_index_entry

cdef object _cinit_bypass_sentinel = object()

cdef IndexEntries wrap_index_entries(lib.AVStream *ptr):
    cdef IndexEntries obj = IndexEntries(_cinit_bypass_sentinel)
    obj._init(ptr)
    return obj


cdef class IndexEntries:
    def __cinit__(self, name):
        if name is _cinit_bypass_sentinel:
            return
        raise RuntimeError("cannot manually instantiate IndexEntries")

    cdef _init(self, lib.AVStream *ptr):
        self.stream_ptr = ptr

    def __repr__(self):
        return f"<av.IndexEntries[{len(self)}]>"

    def __len__(self) -> int:
        with nogil:
            return lib.avformat_index_get_entries_count(self.stream_ptr)

    def __iter__(self) -> Iterator[IndexEntry]: 
        for i in range(len(self)):
            yield self[i]

    def __getitem__(self, index: int | slice) -> IndexEntry | list[IndexEntry | None] | None:
        cdef int c_idx
        if isinstance(index, int):
            if index < 0: 
                index += len(self)
            if index < 0 or index >= len(self):
                raise IndexError(f"Frame index {index} out of bounds for size {len(self)}")

            c_idx = index
            with nogil:
                entry = lib.avformat_index_get_entry(self.stream_ptr, c_idx)

            if entry == NULL:
                return None

            return wrap_index_entry(entry)
        elif isinstance(index, slice):
            start, stop, step = index.indices(len(self))
            return [self[i] for i in range(start, stop, step)]
        else:
            raise TypeError("Index must be an integer or a slice")

    def search_timestamp(self, timestamp, *, bint backward=True, bint any_frame=False):
        cdef int64_t c_timestamp = timestamp
        cdef int flags = 0

        if backward:
            flags |= lib.AVSEEK_FLAG_BACKWARD
        if any_frame:
            flags |= lib.AVSEEK_FLAG_ANY

        with nogil:
            idx = lib.av_index_search_timestamp(self.stream_ptr, c_timestamp, flags)

        return idx

