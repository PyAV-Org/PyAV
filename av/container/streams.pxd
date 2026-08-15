cimport libav as lib

from av.stream cimport Stream


cdef class StreamContainer:
    cdef list[Stream] _streams
    cdef void add_stream(self, Stream stream)
