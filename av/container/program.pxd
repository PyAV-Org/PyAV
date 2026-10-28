cimport libav as lib

from av.container.core cimport Container


cdef class Program:
    cdef Container container
    cdef readonly int index
    cdef lib.AVProgram *_ptr(self)

cdef Program wrap_program(Container container, int index)
