cimport libav as lib

from av.format cimport ContainerFormat


# Since there are multiple objects that need to refer to a valid context, we
# need this intermediate proxy object so that there aren't any reference cycles
# and the pointer can be freed when everything that depends upon it is deleted.
cdef class ContainerProxy(object):
    cdef lib.AVFormatContext *ptr


cdef class Container(object):
    
    cdef readonly bytes name
    cdef readonly ContainerFormat format
    
    cdef ContainerProxy proxy
    cdef object __weakref__
    
    cdef readonly list streams
    cdef readonly dict metadata
    


cdef class InputContainer(Container):
    pass


cdef class OutputContainer(Container):

    cdef bint _started
    cdef bint _done

    cpdef add_stream(self, bytes codec_name, object rate=*)
    cpdef start_encoding(self)
