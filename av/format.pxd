cimport libav as lib

cimport av.codec


# Since there are multiple objects that need to refer to a valid context, we
# need this intermediate proxy object so that there aren't any reference cycles
# and the pointer can be freed when everything that depends upon it is deleted.
cdef class _AVFormatContextProxy(object):
    
    cdef lib.AVFormatContext *ptr


cdef class Context(object):
    
    cdef readonly bytes name
    cdef readonly bytes mode
    
    cdef _AVFormatContextProxy proxy
    
    cdef readonly tuple streams


cdef class Stream(object):
    
    cdef readonly int index
    cdef readonly bytes type
    
    cdef _AVFormatContextProxy ctx_proxy
    
    cdef lib.AVStream *ptr
    
    cdef av.codec.Codec codec

