cimport libav as lib

cdef class SwrContextProxy(object):
    cdef lib.SwrContext *ptr
