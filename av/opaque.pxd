cimport libav as lib
from libc.stdint cimport uint8_t


cdef void noop_free(void *opaque, uint8_t *data) noexcept nogil


cdef class OpaqueContainer:
    cdef dict _objects

    cdef lib.AVBufferRef *add(self, object v)
    cdef object get(self, char *name)
    cdef object pop(self, char *name)


cdef OpaqueContainer opaque_container
