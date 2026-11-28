cimport libav as lib


cdef class Dictionary:
    cdef lib.AVDictionary *ptr
    cpdef Dictionary copy(self)
