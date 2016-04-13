cimport libav as lib


cdef class Option(object):

    cdef lib.AVOption *ptr


cdef Option wrap_option(lib.AVOption *ptr)

