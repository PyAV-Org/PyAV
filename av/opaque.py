# type:ignore
import cython
import cython.cimports.libav as lib
from cython import NULL, sizeof
from cython.cimports.libc.stdint import uint8_t, uintptr_t
from cython.cimports.libc.string import memcpy

u8ptr = cython.typedef(cython.pointer[uint8_t])


@cython.cfunc
@cython.exceptval(check=False)
@cython.nogil
def noop_free(opaque: cython.p_void, data: u8ptr) -> cython.void:
    pass


@cython.cfunc
@cython.exceptval(check=False)
@cython.nogil
def key_free(opaque: cython.p_void, data: u8ptr) -> cython.void:
    name: cython.p_char = cython.cast(cython.p_char, data)
    with cython.gil:
        opaque_container.pop(name)


@cython.cclass
class OpaqueContainer:
    def __cinit__(self):
        self._objects = {}

    @cython.cfunc
    def add(self, v: object) -> cython.pointer[lib.AVBufferRef]:
        # Use object's memory address as key
        key: uintptr_t = cython.cast(cython.longlong, id(v))
        self._objects[key] = v

        data: u8ptr = cython.cast(u8ptr, lib.av_malloc(sizeof(uintptr_t)))
        if data == NULL:
            raise MemoryError("Failed to allocate memory for key")

        memcpy(data, cython.address(key), sizeof(uintptr_t))

        # Create the buffer with our free callback
        buffer_ref: cython.pointer[lib.AVBufferRef] = lib.av_buffer_create(
            data, sizeof(uintptr_t), key_free, NULL, 0
        )

        if buffer_ref == NULL:
            raise MemoryError("Failed to create AVBufferRef")

        return buffer_ref

    def get(self, name) -> object:
        key: uintptr_t = cython.cast(cython.pointer[uintptr_t], name)[0]
        return self._objects.get(key)

    def pop(self, name) -> object:
        key: uintptr_t = cython.cast(cython.pointer[uintptr_t], name)[0]
        return self._objects.pop(key, None)


opaque_container: OpaqueContainer = OpaqueContainer()
