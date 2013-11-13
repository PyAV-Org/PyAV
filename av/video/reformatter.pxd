cimport libav as lib

cdef class VideoReformatter(object):
    cdef lib.SwsContext *ptr
