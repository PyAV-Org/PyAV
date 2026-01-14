cimport libav as lib

cdef class FrameIndex:

    cdef lib.AVStream *stream_ptr
    cdef _init(self, lib.AVStream *ptr)


cdef FrameIndex wrap_frame_index(lib.AVStream *ptr)