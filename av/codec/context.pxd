from libc.stdint cimport int64_t

cimport libav as lib

from av.codec.codec cimport Codec
from av.container.core cimport ContainerProxy
from av.frame cimport Frame
from av.packet cimport Packet


cdef class CodecContext(object):

    cdef lib.AVCodecContext *ptr

    cdef ContainerProxy container

    cdef lib.AVCodecParserContext *parser
    cdef unsigned char *parse_buffer
    cdef size_t parse_buffer_size
    cdef size_t parse_buffer_max_size
    cdef size_t parse_pos

    cdef _init(self, lib.AVCodecContext *ptr, lib.AVCodec *codec)

    cdef readonly Codec codec

    cdef public dict options

    # Public API.
    cpdef open(self, bint strict=?)
    cpdef close(self, bint strict=?)

    # Public version of the send/receive API.
    cdef Frame _next_frame
    cdef Frame _alloc_next_frame(self)
    
    cpdef send(self, input=?)
    cpdef recv(self)

    # Wraps both versions of the APIs, returning lists.
    cpdef encode(self, Frame frame=?, unsigned int count=?, bint prefer_send_recv=?)
    cpdef decode(self, Packet packet=?, unsigned int count=?, bint prefer_send_recv=?)

    # Used by all APIs to setup user-land objects.
    cdef _prepare_frames_for_encode(self, Frame frame, bint drain)
    cdef _setup_encoded_packet(self, Packet)
    cdef _setup_decoded_frame(self, Frame)

    # Implemented by children for the encode/decode API.
    cdef _encode(self, Frame frame)
    cdef _decode(self, lib.AVPacket *packet, int *data_consumed)


cdef CodecContext wrap_codec_context(lib.AVCodecContext*, lib.AVCodec*, ContainerProxy)

