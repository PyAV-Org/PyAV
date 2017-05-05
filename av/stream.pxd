from libc.stdint cimport int64_t

cimport libav as lib

# from av.codec.context cimport CodecContext
from av.container.core cimport Container, ContainerProxy
from av.frame cimport Frame
from av.packet cimport Packet


cdef class Stream(object):
    
    # Stream attributes.
    cdef ContainerProxy _container
    cdef _weak_container
    
    cdef lib.AVStream *_stream
    cdef readonly dict metadata

    # CodecContext attributes.
    cdef lib.AVCodecContext *_codec_context
    cdef lib.AVCodec *_codec
    cdef lib.AVDictionary *_codec_options
    
    # cdef readonly CodecContext codec
    
    # Private API.
    cdef _init(self, Container, lib.AVStream*)
    cdef _setup_frame(self, Frame)
    cdef _decode_one(self, lib.AVPacket*, int *data_consumed)

    # Public API.
    cpdef decode(self, Packet packet, int count=?)


cdef Stream wrap_stream(Container, lib.AVStream*)
