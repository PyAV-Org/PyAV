cimport libav as lib
from libc.stdint cimport int64_t, uint8_t

from av.buffer cimport ByteSource
from av.codec.codec cimport Codec
from av.codec.hwaccel cimport HWAccel
from av.frame cimport Frame
from av.packet cimport Packet


cdef class CodecContext:
    # Fields are laid out in declaration order: pointers first, then the small
    # scalars, so there are no padding holes between them.
    cdef lib.AVCodecContext *ptr
    cdef lib.AVCodecParserContext *parser
    cdef public dict options
    cdef HWAccel hwaccel_ctx
    cdef Frame _next_frame

    cdef uint8_t _ctxflags  # ctxEnum: template_initialized
    # True when created via add_stream_from_template(); start_encoding() skips
    # avcodec_open2() and lets encode()/decode() open the codec lazily if needed.

    cdef _init(self, lib.AVCodecContext *ptr, const lib.AVCodec *codec, HWAccel hwaccel)
    cdef _assert_not_open(self, name)

    cpdef open(self, bint strict=?)
    cpdef encode(self, Frame frame=?)
    cpdef decode(self, Packet packet=?)
    cdef _decode(self, Packet packet)
    cpdef flush_buffers(self)
    cdef _prepare_and_time_rebase_frames_for_encode(self, Frame frame)
    cdef void _setup_encode_hwframes(self)
    cdef list[Frame | None] _prepare_frames_for_encode(self, Frame frame)
    cdef _setup_encoded_packet(self, Packet)
    cdef _setup_decoded_frame(self, Frame, Packet)

    # Implemented by base for the generic send/recv API.
    # Note that the user cannot send without receiving. This is because
    # `_prepare_frames_for_encode` may expand a frame into multiple (e.g. when
    # resampling audio to a higher rate but with fixed size frames), and the
    # send/recv buffer may be limited to a single frame. Ergo, we need to flush
    # the buffer as often as possible.
    cdef _recv_packet(self)
    cdef _recv_frame(self)
    cdef _transfer_hwframe(self, Frame frame)
    cdef Frame _alloc_next_frame(self)

cdef CodecContext wrap_codec_context(lib.AVCodecContext*, const lib.AVCodec*, HWAccel hwaccel)
