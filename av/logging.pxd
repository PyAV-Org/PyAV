cdef extern from "Python.h" nogil:
    void PyErr_PrintEx(int set_sys_last_vars)
    int Py_IsInitialized()
    void PyErr_Display(object, object, object)

cpdef get_last_error()
