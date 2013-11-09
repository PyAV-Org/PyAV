from av.frame cimport Frame


cdef class Plane(object):
    
    cdef Frame frame
    cdef int index

    # Common properties
    cdef readonly size_t buffer_size
    
    # For PEP 3118 buffer protocol.
    cdef Py_ssize_t _buffer_shape[3]
    cdef Py_ssize_t _buffer_strides[3]
    cdef Py_ssize_t _buffer_suboffsets[3]
