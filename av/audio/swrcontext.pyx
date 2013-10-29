
cdef class SwrContextProxy(object):
    def __dealloc__(self):
        lib.swr_free(&self.ptr)
