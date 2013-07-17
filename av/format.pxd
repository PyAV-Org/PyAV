from libc.stdint cimport uint8_t, int64_t

cimport libav as lib

cimport av.codec


# Since there are multiple objects that need to refer to a valid context, we
# need this intermediate proxy object so that there aren't any reference cycles
# and the pointer can be freed when everything that depends upon it is deleted.
cdef class ContextProxy(object):
    
    cdef bint is_input
    cdef lib.AVFormatContext *ptr


cdef class Context(object):
    
    cdef readonly bytes name
    cdef readonly bytes mode
    
    # Mirrors of each other for readibility.
    cdef readonly bint is_input
    cdef readonly bint is_output
    
    cdef ContextProxy proxy
    
    cdef readonly tuple streams
    cdef readonly dict metadata


cdef class Stream(object):
    
    cdef readonly bytes type
    
    cdef ContextProxy ctx_proxy
    cdef Context ctx
    
    cdef lib.AVStream *ptr
    
    cdef av.codec.Codec codec
    cdef readonly dict metadata
    
    cdef int64_t last_pts
    
    cdef flush_buffers(self)
    
    cpdef frame_to_pts(self, int frame)
    cpdef pts_to_frame(self, int64_t timestamp)
    cpdef seek(self, int64_t timestamp, mode=*)
    cpdef decode(self, av.codec.Packet packet)


cdef class VideoStream(Stream):
    
    cdef readonly int buffer_size
    
    # Hold onto the frames that we will decode until we have a full one.
    cdef lib.AVFrame *raw_frame
    cdef lib.AVFrame *rgb_frame
    cdef uint8_t *buffer_
    cdef lib.SwsContext *sws_ctx
    cdef int last_w
    cdef int last_h


cdef class AudioStream(Stream):

    # Hold onto the frames that we will decode until we have a full one.
    cdef lib.AVFrame *frame

