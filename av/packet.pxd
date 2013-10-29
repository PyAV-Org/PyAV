
cdef class Packet(object):

    cdef readonly av.format.Stream stream
    cdef lib.AVPacket struct
    cdef readonly bool is_null
