cimport libav as lib
from av.packet cimport Packet
from av.container cimport Container, ContainerProxy
from av.frame cimport Frame
from libc.stdint cimport int64_t

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
    
    cdef int64_t packet_pts
    
    # cdef lib.AVRational _frame_rate

    # API.
    cdef _init(self, Container, lib.AVStream*)
    cpdef decode(self, Packet)
    cdef _flush_decoder_frames(self)
    cdef _setup_frame(self, Frame)
    cdef _decode_one(self, lib.AVPacket*, int *data_consumed)


cdef Stream build_stream(Container, lib.AVStream*)
