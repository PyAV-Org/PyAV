cimport libav as lib

cdef class SwsContextProxy(object):
    cdef lib.SwsContext *ptr
