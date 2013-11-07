cimport libav as lib


cdef class Descriptor(object):

    cdef lib.AVPixelFormat pix_fmt
    cdef lib.AVPixFmtDescriptor *ptr
    cdef readonly unsigned int width, height

    cdef readonly tuple components

    cpdef chroma_width(self, unsigned int luma_width=?)
    cpdef chroma_height(self, unsigned int luma_height=?)


cdef class ComponentDescriptor(object):

    cdef Descriptor format
    cdef readonly unsigned int index
    cdef lib.AVComponentDescriptor *ptr
