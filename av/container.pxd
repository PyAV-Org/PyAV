cimport libav as lib


# Since there are multiple objects that need to refer to a valid context, we
# need this intermediate proxy object so that there aren't any reference cycles
# and the pointer can be freed when everything that depends upon it is deleted.
cdef class ContainerProxy(object):
    
    cdef bint is_input
    cdef lib.AVFormatContext *ptr


cdef class Container(object):
    
    cdef readonly bytes name
    
    cdef ContainerProxy proxy
    cdef object __weakref__
    
    cdef readonly list streams
    cdef readonly dict metadata
    


cdef class InputContainer(Container):
    pass


cdef class OutputContainer(Container):
    cpdef add_stream(self, bytes codec_name, object rate=*)
    cpdef start_encoding(self)
