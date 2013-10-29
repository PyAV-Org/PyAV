cimport libav as lib

cdef class SwsContextProxy(object):
    def __dealloc__(self):
        lib.sws_freeContext(self.ptr)
