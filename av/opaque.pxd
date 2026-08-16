cimport libav as lib
from libc.stdint cimport uint64_t


cdef class OpaqueContainer:
    cdef dict _objects
    cdef uint64_t _next_key
    cdef lib.AVBufferRef *add(self, object v)
    cdef object get(self, char *name)
    cdef object pop(self, char *name)


cdef OpaqueContainer opaque_container
