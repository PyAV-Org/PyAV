cimport libav as lib


cdef class ContainerFormat(object):

    cdef readonly bytes name
    
    cdef lib.AVInputFormat *in_
    cdef lib.AVOutputFormat *out

