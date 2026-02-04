cimport libav as lib


cdef class Dictionary:
    cdef lib.AVDictionary *ptr
    cpdef Dictionary copy(self)

cdef Dictionary wrap_dictionary(lib.AVDictionary *input_)
