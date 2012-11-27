cimport libav as lib

cimport av.codec


# Since there are multiple objects that need to refer to a valid context, we
# need this intermediate proxy object so that there aren't any reference cycles
# and the pointer can be freed when everything that depends upon it is deleted.
cdef class ContextProxy(object):
    
    cdef bint is_input
    cdef lib.AVFormatContext *ptr


cdef class Context(object):
    
    cdef readonly bytes name
    cdef readonly bytes mode
    
    # Mirrors of each other for readibility.
    cdef readonly bint is_input
    cdef readonly bint is_output
    
    cdef ContextProxy proxy
    
    cdef readonly tuple streams
    cdef readonly dict metadata


cdef class Stream(object):
    
    cdef readonly bytes type
    
    cdef ContextProxy ctx_proxy
    
    cdef lib.AVStream *ptr
    
    cdef av.codec.Codec codec
    cdef readonly dict metadata
    
    cpdef decode(self, av.codec.Packet packet)


