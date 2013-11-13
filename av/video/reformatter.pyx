cimport libav as lib

cdef class VideoReformatter(object):
    def __dealloc__(self):
        lib.sws_freeContext(self.ptr)
