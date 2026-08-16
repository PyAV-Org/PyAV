# type:ignore
import cython
import cython.cimports.libav as lib
from cython import NULL, sizeof
from cython.cimports.libc.stdint import uint8_t, uint64_t
from cython.cimports.libc.string import memcpy

u8ptr = cython.typedef(cython.pointer[uint8_t])


@cython.cfunc
@cython.exceptval(check=False)
@cython.nogil
def key_free(opaque: cython.p_void, data: u8ptr) -> cython.void:
    name: cython.p_char = cython.cast(cython.p_char, data)
    with cython.gil:
        opaque_container.pop(name)
    lib.av_free(data)


@cython.final
@cython.cclass
class OpaqueContainer:
    def __cinit__(self):
        self._objects = {}
        self._next_key = 0

    @cython.cfunc
    def add(self, v: object) -> cython.pointer[lib.AVBufferRef]:
        # A fresh key per buffer. Keying on id(v) instead would give the same key
        # to one object held by two frames, and freeing either would drop the
        # entry out from under the other.
        key: uint64_t = self._next_key

        data: u8ptr = cython.cast(u8ptr, lib.av_malloc(sizeof(uint64_t)))
        if data == NULL:
            raise MemoryError("Failed to allocate memory for key")

        memcpy(data, cython.address(key), sizeof(uint64_t))

        # Create the buffer with our free callback
        buffer_ref: cython.pointer[lib.AVBufferRef] = lib.av_buffer_create(
            data, sizeof(uint64_t), key_free, NULL, 0
        )

        if buffer_ref == NULL:
            # av_buffer_create() leaves the data to us when it fails.
            lib.av_free(data)
            raise MemoryError("Failed to create AVBufferRef")

        # Register only once key_free() is in place to unregister it again.
        self._objects[key] = v
        self._next_key += 1
        return buffer_ref

    def get(self, name) -> object:
        key: uint64_t = cython.cast(cython.pointer[uint64_t], name)[0]
        return self._objects.get(key)

    def pop(self, name) -> object:
        key: uint64_t = cython.cast(cython.pointer[uint64_t], name)[0]
        return self._objects.pop(key, None)


opaque_container = OpaqueContainer()
