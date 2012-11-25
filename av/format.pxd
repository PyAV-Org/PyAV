cimport libav as lib


cdef class Context(object):
    
    cdef readonly bytes name
    cdef readonly bytes mode
    
    cdef lib.AVFormatContext *ptr
