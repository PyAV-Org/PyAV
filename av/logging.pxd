cimport libav as lib


cdef extern from "Python.h" nogil:
    void PyErr_PrintEx(int set_sys_last_vars)
    int Py_IsInitialized()
    void PyErr_Display(object, object, object)

cdef extern from "stdio.h" nogil:
    cdef int vsnprintf(char *output, int n, const char *format, lib.va_list args)

cpdef get_last_error()
