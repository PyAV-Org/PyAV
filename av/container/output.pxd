cimport libav as lib

from av.container.core cimport Container
from av.stream cimport Stream


cdef class OutputContainer(Container):

    cdef bint _started
    cdef bint _done

    cpdef start_encoding(self)
