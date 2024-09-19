cimport libav as lib


cdef class OpaqueContainer:
    cdef dict _by_name

    cdef lib.AVBufferRef *add(self, object v)
    cdef object get(self, bytes name)
    cdef object pop(self, bytes name)


cdef OpaqueContainer opaque_container
