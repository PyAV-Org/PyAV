cimport libav as lib




cdef class Descriptor(object):

    cdef lib.AVPixelFormat pix_fmt
    cdef lib.AVPixFmtDescriptor *ptr
    cdef readonly tuple components

cdef class ComponentDescriptor(object):

    cdef Descriptor format
    cdef lib.AVComponentDescriptor *ptr
