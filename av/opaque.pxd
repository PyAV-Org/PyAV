cimport libav as lib


cdef class OpaqueContainer:
    cdef dict _objects

    cdef lib.AVBufferRef *add(self, object v)
    cdef object get(self, char *name)
    cdef object pop(self, char *name)


cdef OpaqueContainer opaque_container
