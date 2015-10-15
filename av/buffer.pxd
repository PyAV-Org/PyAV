
cdef class _Buffer(object):

    cdef size_t _buffer_size(self)
    cdef void* _buffer_ptr(self)


cdef class Buffer(_Buffer):
    pass
