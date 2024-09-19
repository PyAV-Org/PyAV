cimport libav as lib
from libc.stdint cimport uint8_t

from uuid import uuid4


cdef void key_free(void *opaque, uint8_t *data) noexcept nogil:
    cdef char *name = <char *>data
    with gil:
        opaque_container.pop(name)


cdef class OpaqueContainer:
    """A container that holds references to Python objects, indexed by uuid"""

    def __cinit__(self):
        self._by_name = {}

    cdef lib.AVBufferRef *add(self, v):
        cdef bytes uuid = str(uuid4()).encode("utf-8")
        cdef lib.AVBufferRef *ref = lib.av_buffer_create(uuid, len(uuid), &key_free, NULL, 0)
        self._by_name[uuid] = v
        return ref

    cdef object get(self, bytes name):
        return self._by_name.get(name)

    cdef object pop(self, bytes name):
        return self._by_name.pop(name)


cdef opaque_container = OpaqueContainer()
