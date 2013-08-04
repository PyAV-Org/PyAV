from libc.stdint cimport uint8_t

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
    
    cdef readonly list streams
    cdef readonly dict metadata
    
    cpdef add_stream(self, char* codec_name)
    
    cpdef begin_encoding(self)


cdef class Stream(object):
    
    cdef readonly bytes type
    
    cdef ContextProxy ctx_proxy
    
    cdef lib.AVStream *ptr
    
    cdef readonly av.codec.Codec codec
    cdef readonly dict metadata
    
    cpdef decode(self, av.codec.Packet packet)


cdef class VideoStream(Stream):
    
    cdef readonly int buffer_size
    
    # Hold onto the frames that we will decode until we have a full one.
    cdef lib.AVFrame *raw_frame
    cdef av.codec.SwsContextProxy sws_proxy
    cdef int last_w
    cdef int last_h
    
    cpdef encode(self, av.codec.VideoFrame)
    
    cpdef flush_encoder(self)


cdef class AudioStream(Stream):

    # Hold onto the frames that we will decode until we have a full one.
    cdef lib.AVFrame *frame

