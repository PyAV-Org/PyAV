cimport libav as lib

from av.stream cimport Stream


cdef class Packet(object):

    cdef Stream stream
    cdef lib.AVPacket struct
