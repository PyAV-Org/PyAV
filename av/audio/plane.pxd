from av.plane cimport Plane


cdef class AudioPlane(Plane):
    cdef size_t _buffer_size(self)
