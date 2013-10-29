cimport libav as lib


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
    
    cdef readonly list streams
    cdef readonly dict metadata
    
    cpdef add_stream(self, bytes codec_name, object rate=*)
    
    cpdef start_encoding(self)