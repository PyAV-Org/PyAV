from libc.stdint cimport int64_t

cimport libav as lib

from av.container.core cimport Container, ContainerProxy
from av.frame cimport Frame
from av.packet cimport Packet
from av.codec cimport CodecContext

cdef class Stream(object):
    
    # Stream attributes.
    cdef ContainerProxy _container
    cdef _weak_container
    
    cdef lib.AVStream *_stream
    cdef readonly dict metadata

    cdef readonly CodecContext coder

    # CodecContext attributes.
    cdef lib.AVCodecContext *_codec_context
    cdef lib.AVCodec *_codec
    cdef lib.AVDictionary *_codec_options
    
    # Private API.
    cdef _init(self, Container, lib.AVStream*)
    cdef _setup_frame(self, Frame)

    # Public API.
    cpdef decode(self, Packet packet, int count=?)


cdef Stream build_stream(Container, lib.AVStream*)
