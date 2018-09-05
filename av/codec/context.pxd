from libc.stdint cimport int64_t

cimport libav as lib

from av.codec.codec cimport Codec
from av.container.core cimport ContainerProxy
from av.frame cimport Frame
from av.packet cimport Packet
from av.bytesource cimport ByteSource


cdef class CodecContext(object):

    cdef lib.AVCodecContext *ptr

    cdef ContainerProxy container

    # Used as a signal that this is within a stream, and also for us to access
    # that stream. This is set "manually" by the stream after constructing
    # this object.
    cdef int stream_index

    cdef lib.AVCodecParserContext *parser
    cdef unsigned char *parse_buffer
    cdef size_t parse_buffer_size
    cdef size_t parse_buffer_max_size
    cdef size_t parse_pos

    # To hold a reference to passed extradata.
    cdef ByteSource extradata_source

    cdef _init(self, lib.AVCodecContext *ptr, lib.AVCodec *codec)

    cdef readonly Codec codec

    cdef public dict options

    # Public API.
    cpdef open(self, bint strict=?)
    cpdef close(self, bint strict=?)

    cdef _set_default_time_base(self)

    # Wraps both versions of the transcode API, returning lists.
    cpdef encode(self, Frame frame=?, unsigned int count=?, bint prefer_send_recv=?)
    cpdef decode(self, Packet packet=?, unsigned int count=?, bint prefer_send_recv=?)

    # Used by both transcode APIs to setup user-land objects.
    cdef _prepare_frames_for_encode(self, Frame frame)
    cdef _setup_encoded_packet(self, Packet, Frame)
    cdef _setup_decoded_frame(self, Frame, Packet)

    # Implemented by children for the encode/decode API.
    cdef _encode(self, Frame frame)
    cdef _decode(self, lib.AVPacket *packet, int *data_consumed)

    # Implemented by base for the generic send/recv API.
    # Note that the user cannot send without recieving. This is because
    # _prepare_frames_for_encode may expand a frame into multiple (e.g. when
    # resampling audio to a higher rate but with fixed size frames), and the
    # send/recv buffer may be limited to a single frame. Ergo, we need to flush
    # the buffer as often as possible.
    cdef _send_frame_and_recv(self, Frame frame)
    cdef _recv_packet(self)
    cdef _send_packet_and_recv(self, Packet packet)
    cdef _recv_frame(self)

    # Implemented by children for the generic send/recv API, so we have the
    # correct subclass of Frame.
    cdef Frame _next_frame
    cdef Frame _alloc_next_frame(self)


cdef CodecContext wrap_codec_context(lib.AVCodecContext*, lib.AVCodec*, ContainerProxy)
