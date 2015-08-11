cimport libav as lib

from av.container.core cimport Container
from av.stream cimport Stream



cdef class OutputContainer(Container):

    cdef bint _started
    cdef bint _done

    cpdef add_stream(self, codec_name=*, object rate=*, Stream template=*)
    cpdef start_encoding(self)
