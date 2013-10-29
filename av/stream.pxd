cimport libav as lib
from av.codec cimport Codec
from av.packet cimport Packet
from av.context cimport Context, ContextProxy


cdef class Stream(object):
    
    cdef readonly bytes type
    
    cdef ContextProxy ctx
    
    cdef lib.AVStream *ptr
    
    cdef readonly Codec codec
    cdef readonly dict metadata
    
    cpdef decode(self, Packet packet)


cdef Stream stream_factory(Context ctx, int index)
