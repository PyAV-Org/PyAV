from libc.stdint cimport uint8_t, int64_t
from libc.string cimport memcpy
from libc.stdlib cimport malloc, realloc, free
from cpython cimport PyWeakref_NewRef

cimport libav as lib

from av.codec.codec cimport Codec, wrap_codec
from av.packet cimport Packet
from av.utils cimport err_check, avdict_to_dict, avrational_to_faction, to_avrational, media_type_to_string






cdef object _cinit_sentinel = object()


cdef CodecContext wrap_codec_context(lib.AVCodecContext *c_ctx, lib.AVCodec *c_codec, bint owns_ptr):
    """Build an av.CodecContext for an existing AVCodecContext."""
    
    cdef CodecContext py_ctx

    # TODO: This.
    if c_ctx.codec_type == lib.AVMEDIA_TYPE_VIDEO:
        from av.video.codeccontext import VideoCodecContext
        py_ctx = VideoCodecContext(_cinit_sentinel)
    elif c_ctx.codec_type == lib.AVMEDIA_TYPE_AUDIO:
        from av.audio.codeccontext import AudioCodecContext
        py_ctx = AudioCodecContext(_cinit_sentinel)
    elif c_ctx.codec_type == lib.AVMEDIA_TYPE_SUBTITLE:
        from av.subtitles.codeccontext import SubtitleCodecContext
        py_ctx = SubtitleCodecContext(_cinit_sentinel)
    else:
        py_ctx = CodecContext(_cinit_sentinel)

    py_ctx._owns_ptr = owns_ptr
    py_ctx._init(c_ctx, c_codec)

    return py_ctx


cdef class CodecContext(object):
    
    @staticmethod
    def create(codec, mode=None):
        cdef Codec cy_codec = codec if isinstance(codec, Codec) else Codec(codec, mode)
        cdef lib.AVCodecContext *c_ctx = lib.avcodec_alloc_context3(cy_codec.ptr)
        err_check(lib.avcodec_get_context_defaults3(c_ctx, cy_codec.ptr))
        return wrap_codec_context(c_ctx, cy_codec.ptr, True)

    def __cinit__(self, sentinel=None, *args, **kwargs):
        if sentinel is not _cinit_sentinel:
            raise RuntimeError('Cannot instantiate CodecContext')

    cdef _init(self, lib.AVCodecContext *ptr, lib.AVCodec *codec):
        self.ptr = ptr
        if self.ptr.codec and codec and self.ptr.codec != codec:
            raise RuntimeError('Wrapping CodecContext with mismatched codec.')
        self.codec = wrap_codec(codec if codec != NULL else self.ptr.codec)

    @property
    def is_open(self):
        return lib.avcodec_is_open(self.ptr)

    cpdef open(self, bint strict=True):

        if lib.avcodec_is_open(self.ptr):
            if strict:
                raise ValueError('CodecContext is already open.')
            return

        # We might pass partial frames.
        if self.codec.ptr.capabilities & lib.CODEC_CAP_TRUNCATED:
            self.ptr.flags |= lib.CODEC_FLAG_TRUNCATED

        # TODO: Options
        err_check(lib.avcodec_open2(self.ptr, self.codec.ptr, NULL))

    cpdef close(self, bint strict=True):
        if not lib.avcodec_is_open(self.ptr):
            if strict:
                raise ValueError('CodecContext is already closed.')
            return
        err_check(lib.avcodec_close(self.ptr))

    def __dealloc__(self):
        if self.ptr and self._owns_ptr:
            lib.avcodec_close(self.ptr)
            lib.avcodec_free_context(&self.ptr)
        if self.parser:
            lib.av_parser_close(self.parser)
        if self.parse_buffer:
            free(self.parse_buffer)

    def __repr__(self):
        return '<av.%s %s/%s at 0x%x>' % (
            self.__class__.__name__,
            self.type or '<notype>',
            self.name or '<nocodec>',
            id(self),
        )

    def parse(self, str input_, allow_stream=False):

        if not self.parser:
            self.parser = lib.av_parser_init(self.codec.ptr.id)
        if not self.parser:
            if allow_stream:
                return [Packet(input_)]
            else:
                raise ValueError('no parser for %s' % self.codec.name)

        cdef size_t new_buffer_size
        cdef unsigned char *c_input
        if input_ is not None:

            # Make sure we have enough buffer.
            new_buffer_size = self.parse_buffer_size + len(input_)
            if new_buffer_size > self.parse_buffer_max_size:
                self.parse_buffer = <unsigned char*>realloc(<void*>self.parse_buffer, new_buffer_size)
                self.parse_buffer_max_size = new_buffer_size

            # Copy to the end of the buffer.
            c_input = input_ # for casting
            memcpy(self.parse_buffer + self.parse_buffer_size, c_input, len(input_))
            self.parse_buffer_size = new_buffer_size

        cdef size_t base = 0
        cdef size_t used = 0 # To signal to the while.
        cdef Packet packet = None
        packets = []

        while base < self.parse_buffer_size:
            packet = Packet()
            with nogil:
                used = lib.av_parser_parse2(
                    self.parser,
                    self.ptr,
                    &packet.struct.data, &packet.struct.size,
                    self.parse_buffer + base, self.parse_buffer_size - base,
                    0, 0,
                    self.parse_pos
                )
            err_check(used)

            if packet.struct.size:
                packets.append(packet)
            if used:
                self.parse_pos += used
                base += used

            if not (used or packet.struct.size):
                break

        if base:
            # Shuffle the buffer.
            memcpy(self.parse_buffer, self.parse_buffer + base, base)
            self.parse_buffer_size -= base

        return packets

    cpdef encode(self, Frame frame=None):
        cdef Packet packet = self._encode(frame)
        if packet:
            packet._time_base = self.ptr.time_base
            return packet

    cdef _encode(self, Frame frame):
        raise NotImplementedError('Base CodecContext cannot encode frames.')

    cpdef decode(self, Packet packet, int count=0):
        """Decode a list of :class:`.Frame` from the given :class:`.Packet`.

        If the packet is None, the buffers will be flushed. This is useful if
        you do not want the library to automatically re-order frames for you
        (if they are encoded with a codec that has B-frames).

        """

        if packet is None:
            packet = Packet() # Makes our control flow easier.

        if not self.codec.ptr:
            raise ValueError('cannot decode unknown codec')

        self.open(strict=False)

        cdef int data_consumed = 0
        cdef list decoded_objs = []

        cdef uint8_t *original_data = packet.struct.data
        cdef int      original_size = packet.struct.size

        cdef bint is_flushing = not (packet.struct.data and packet.struct.size)

        # Keep decoding while there is data.
        while is_flushing or packet.struct.size > 0:

            if is_flushing:
                packet.struct.data = NULL
                packet.struct.size = 0

            decoded = self._decode_one(&packet.struct, &data_consumed)
            packet.struct.data += data_consumed
            packet.struct.size -= data_consumed
            
            if decoded:

                if isinstance(decoded, Frame):
                    self._setup_decoded_frame(decoded)
                decoded_objs.append(decoded)

                # Sometimes we will error if we try to flush the stream
                # (e.g. MJPEG webcam streams), and so we must be able to
                # bail after the first, even though buffers may build up.
                if count and len(decoded_objs) >= count:
                    break

            # Sometimes there are no frames, and no data is consumed, and this
            # is ok. However, no more frames are going to be pulled out of here.
            # (It is possible for data to not be consumed as long as there are
            # frames, e.g. during flushing.)
            elif not data_consumed:
                break

        # Restore the packet.
        packet.struct.data = original_data
        packet.struct.size = original_size

        return decoded_objs
    
    cdef _setup_decoded_frame(self, Frame frame):

        # In FFMpeg <= 3.0, and all LibAV we know of, the frame's pts may be
        # unset at this stage, and he PTS from a packet is the correct one while
        # decoding, and it is copied to pkt_pts during creation of a frame.
        # TODO: Look into deprecation of pkt_pts in FFmpeg > 3.0
        if frame.ptr.pts == lib.AV_NOPTS_VALUE:
            frame.ptr.pts = frame.ptr.pkt_pts

        # We don't have to worry about context vs. stream time_base during decoding
        # as they should be the same.
        frame._time_base = self.ptr.time_base
        
        frame.index = self.ptr.frame_number - 1
 
    cdef _decode_one(self, lib.AVPacket *packet, int *data_consumed):
        raise NotImplementedError('Base CodecContext cannot decode packets.')

    property time_base:
        def __get__(self):
            return avrational_to_faction(&self.ptr.time_base)
        def __set__(self, value):
            to_avrational(value, &self.ptr.time_base)

    property name:
        def __get__(self):
            return self.codec.name

    property type:
        def __get__(self):
            return self.codec.type
        
    property rate:
        def __get__(self):
            if self.ptr:
                return self.ptr.ticks_per_frame * avrational_to_faction(&self.ptr.time_base)

    property bit_rate:
        def __get__(self):
            return self.ptr.bit_rate if self.ptr and self.ptr.bit_rate > 0 else None
        def __set__(self, int value):
            self.ptr.bit_rate = value

    property max_bit_rate:
        def __get__(self):
            if self.ptr and self.ptr.rc_max_rate > 0:
                return self.ptr.rc_max_rate
            else:
                return None
            
    property bit_rate_tolerance:
        def __get__(self):
            return self.ptr.bit_rate_tolerance if self.ptr else None
        def __set__(self, int value):
            self.ptr.bit_rate_tolerance = value

    # TODO: Does it conceptually make sense that this is on streams, instead
    # of on the container?
    property thread_count:
        def __get__(self):
            return self.ptr.thread_count
        def __set__(self, int value):
            self.ptr.thread_count = value



