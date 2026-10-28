cimport libav as lib

from av.container.core cimport Container
from av.stream cimport Stream


cdef class InputContainer(Container):
    cdef void flush_buffers(self)


cdef class Program:
    cdef InputContainer container
    cdef readonly int index
    cdef lib.AVProgram *_ptr(self)

cdef Program wrap_program(InputContainer container, int index)
