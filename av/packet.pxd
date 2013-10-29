cimport libav as lib

from av.stream cimport Stream


cdef class Packet(object):

    cdef readonly Stream stream
    cdef lib.AVPacket struct
    cdef readonly bint is_null
