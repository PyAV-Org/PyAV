cimport libav as lib

from av.sidedata.sidedata cimport SideData


cdef class VideoEncParams(SideData):
    pass


cdef class VideoBlockParams:
    cdef lib.AVVideoBlockParams *ptr
