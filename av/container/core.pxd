cimport libav as lib

from av.container.streams cimport StreamContainer
from av.dictionary cimport _Dictionary
from av.format cimport ContainerFormat
from av.stream cimport Stream

# Since there are multiple objects that need to refer to a valid context, we
# need this intermediate proxy object so that there aren't any reference cycles
# and the pointer can be freed when everything that depends upon it is deleted.
cdef class ContainerProxy(object):

    cdef bint writeable
    cdef lib.AVFormatContext *ptr

    cdef seek(self, int stream_index, lib.int64_t timestamp, str mode, bint backward, bint any_frame)
    cdef flush_buffers(self)

    cdef str name

    # File-like source.
    cdef object file
    cdef object fread
    cdef object fwrite
    cdef object fseek
    cdef object ftell

    # Custom IO for above.
    cdef lib.AVIOContext *iocontext
    cdef long bufsize
    cdef unsigned char *buffer
    cdef long pos
    cdef bint pos_is_valid
    
    cdef int err_check(self, int value) except -1


cdef class Container(object):
    
    cdef readonly str name
    cdef readonly object file

    cdef readonly bint writeable

    cdef readonly ContainerFormat format
    cdef _Dictionary options

    cdef ContainerProxy proxy
    cdef object __weakref__

    cdef readonly StreamContainer streams
    cdef readonly dict metadata

