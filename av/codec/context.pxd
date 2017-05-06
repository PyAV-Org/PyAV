from libc.stdint cimport int64_t

cimport libav as lib

from av.codec.codec cimport Codec
from av.frame cimport Frame
from av.packet cimport Packet


cdef class CodecContext(object):

    cdef lib.AVCodecContext *ptr

    # Does this object own its `ptr`? If it is from a stream, it does not.
    # If it is standalone, it does.
    # TODO: This should be a reference to the ContainerProxy, as that
    # is the only reason we would have to not own the poitner at this point.
    cdef bint _owns_ptr

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
    cpdef encode(self, Frame frame=?)
    cdef _encode(self, Frame frame)
    cpdef decode(self, Packet packet, int count=?)
    cdef _decode_one(self, lib.AVPacket *packet, int *data_consumed)
    cdef _setup_decoded_frame(self, Frame)


cdef CodecContext wrap_codec_context(lib.AVCodecContext*, lib.AVCodec*, bint owns_ptr)

