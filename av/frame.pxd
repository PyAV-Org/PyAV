cimport libav as lib

cdef class Frame(object):
    cdef lib.AVFrame *ptr
    cdef lib.AVRational time_base_
