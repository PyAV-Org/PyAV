cimport libav as lib

cdef class VideoReformatter(object):
    def __dealloc__(self):
        with nogil: lib.sws_freeContext(self.ptr)
