
cdef class SwsContextProxy(object):

    cdef lib.SwsContext *ptr


cdef class VideoFrame(Frame):

    cdef int buffer_size
    cdef uint8_t *buffer_
    cdef readonly int frame_index
    
    cdef SwsContextProxy sws_proxy
    cpdef reformat(self, int width, int height, char* pix_fmt)
