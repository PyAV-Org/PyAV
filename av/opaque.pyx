cimport libav as lib
from libc.stdint cimport uint8_t
from libc.string cimport memcpy


cdef void key_free(void *opaque, uint8_t *data) noexcept nogil:
    cdef char *name = <char *>data
    with gil:
        opaque_container.pop(name)


cdef class OpaqueContainer:
    def __cinit__(self):
        self._objects = {}

    cdef lib.AVBufferRef *add(self, object v):
        # Use object's memory address as key
        cdef size_t key = id(v)
        self._objects[key] = v

        cdef uint8_t *data = <uint8_t *>lib.av_malloc(sizeof(size_t))
        if data == NULL:
            raise MemoryError("Failed to allocate memory for key")

        memcpy(data, &key, sizeof(size_t))

        # Create the buffer with our free callback
        cdef lib.AVBufferRef *buffer_ref = lib.av_buffer_create(
            data, sizeof(size_t), key_free, NULL, 0
        )

        if buffer_ref == NULL:
            raise MemoryError("Failed to create AVBufferRef")

        return buffer_ref

    cdef object get(self, char *name):
        cdef size_t key = (<size_t *>name)[0]
        return self._objects.get(key)

    cdef object pop(self, char *name):
        cdef size_t key = (<size_t *>name)[0]
        return self._objects.pop(key, None)


cdef OpaqueContainer opaque_container = OpaqueContainer()
