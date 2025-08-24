cimport libav as lib

from av.container.core cimport Container
from av.stream cimport Stream


cdef class InputContainer(Container):

    cdef bint eof

    cdef flush_buffers(self)
