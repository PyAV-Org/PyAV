cimport libav as lib
from av.packet cimport Packet
from av.container cimport Container, ContainerProxy
from av.frame cimport Frame


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
    
    # cdef lib.AVRational _frame_rate


    # API.
    cpdef decode(self, Packet packet)
    cdef _setup_frame(self, Frame frame)
    cdef Frame _decode_one(self, lib.AVPacket *packet, int *data_consumed)


cdef Stream stream_factory(Container ctx, int index)
