cimport libav as lib

from av.frame cimport Frame
from av.sidedata.sidedata cimport SideData


cdef class MotionVectors(SideData):
    cdef dict _vectors
    cdef Py_ssize_t _len


cdef class MotionVector:
    cdef MotionVectors parent
    cdef lib.AVMotionVector *ptr
