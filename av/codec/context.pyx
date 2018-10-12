from libc.errno cimport EAGAIN
from libc.stdint cimport uint8_t, int64_t
from libc.stdlib cimport malloc, realloc, free
from libc.string cimport memcpy

cimport libav as lib

from av.bytesource cimport ByteSource, bytesource
from av.codec.codec cimport Codec, wrap_codec
from av.dictionary cimport _Dictionary
from av.dictionary import Dictionary
from av.enums cimport EnumType, define_enum
from av.packet cimport Packet
from av.utils cimport err_check, avdict_to_dict, avrational_to_fraction, to_avrational


cdef object _cinit_sentinel = object()


cdef CodecContext wrap_codec_context(lib.AVCodecContext *c_ctx, const lib.AVCodec *c_codec, bint allocated):
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

    py_ctx.allocated = allocated
    py_ctx._init(c_ctx, c_codec)

    return py_ctx


cdef EnumType _ThreadType = define_enum('ThreadType', (
    ('NONE', 0),
    ('FRAME', lib.FF_THREAD_FRAME),
    ('SLICE', lib.FF_THREAD_SLICE),
    ('AUTO', lib.FF_THREAD_SLICE | lib.FF_THREAD_FRAME),
), is_flags=True)
ThreadType = _ThreadType

cdef EnumType _SkipType = define_enum('SkipType', (
    ('NONE', lib.AVDISCARD_NONE),
    ('DEFAULT', lib.AVDISCARD_DEFAULT),
    ('NONREF', lib.AVDISCARD_NONREF),
    ('BIDIR', lib.AVDISCARD_BIDIR),
    ('NONINTRA', lib.AVDISCARD_NONINTRA),
    ('NONKEY', lib.AVDISCARD_NONKEY),
    ('ALL', lib.AVDISCARD_ALL),
))
SkipType = _SkipType

cdef class CodecContext(object):

    @staticmethod
    def create(codec, mode=None):
        cdef Codec cy_codec = codec if isinstance(codec, Codec) else Codec(codec, mode)
        cdef lib.AVCodecContext *c_ctx = lib.avcodec_alloc_context3(cy_codec.ptr)
        return wrap_codec_context(c_ctx, cy_codec.ptr, True)

    def __cinit__(self, sentinel=None, *args, **kwargs):
        if sentinel is not _cinit_sentinel:
            raise RuntimeError('Cannot instantiate CodecContext')
        
        self.options = {}
        self.stream_index = -1 # This is set by the container immediately.


    cdef _init(self, lib.AVCodecContext *ptr, const lib.AVCodec *codec):

        self.ptr = ptr
        if self.ptr.codec and codec and self.ptr.codec != codec:
            raise RuntimeError('Wrapping CodecContext with mismatched codec.')
        self.codec = wrap_codec(codec if codec != NULL else self.ptr.codec)

        # Set reasonable threading defaults.
        # count == 0 -> use as many threads as there are CPUs.
        # type == 2 -> thread within a frame. This does not change the API.
        self.ptr.thread_count = 0
        self.ptr.thread_type = 2


    property extradata:
        def __get__(self):
            if self.ptr.extradata_size > 0:
                return <bytes>(<uint8_t*>self.ptr.extradata)[:self.ptr.extradata_size]
            else:
                return None
        def __set__(self, data):
            self.extradata_source = bytesource(data)
            self.ptr.extradata = self.extradata_source.ptr
            self.ptr.extradata_size = self.extradata_source.size

    property extradata_size:
        def __get__(self):
            return self.ptr.extradata_size

    property is_open:
        def __get__(self):
            return lib.avcodec_is_open(self.ptr)

    property is_encoder:
        def __get__(self):
            return lib.av_codec_is_encoder(self.ptr.codec)
    property is_decoder:
        def __get__(self):
            return lib.av_codec_is_decoder(self.ptr.codec)

    cpdef open(self, bint strict=True):

        if lib.avcodec_is_open(self.ptr):
            if strict:
                raise ValueError('CodecContext is already open.')
            return

        # We might pass partial frames.
        # TODO: What is this for?! This is causing problems with raw decoding
        # as the internal parser doesn't seem to see a frame until it sees
        # the next one.
        # if self.codec.ptr.capabilities & lib.CODEC_CAP_TRUNCATED:
        #     self.ptr.flags |= lib.CODEC_FLAG_TRUNCATED

        # TODO: Do this better.
        cdef _Dictionary options = Dictionary()
        options.update(self.options or {})

        # Assert we have a time_base.
        if not self.ptr.time_base.num:
            self._set_default_time_base()

        err_check(lib.avcodec_open2(self.ptr, self.codec.ptr, &options.ptr))

        self.options = dict(options)

    cdef _set_default_time_base(self):
        self.ptr.time_base.num = 1
        self.ptr.time_base.den = lib.AV_TIME_BASE

    cpdef close(self, bint strict=True):
        if not lib.avcodec_is_open(self.ptr):
            if strict:
                raise ValueError('CodecContext is already closed.')
            return
        err_check(lib.avcodec_close(self.ptr))

    def __dealloc__(self):
        if self.ptr and self.allocated:
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

    cdef _send_frame_and_recv(self, Frame frame):

        cdef Packet packet

        cdef int res
        with nogil:
            res = lib.avcodec_send_frame(self.ptr, frame.ptr if frame is not None else NULL)
        err_check(res)

        out = []
        while True:
            packet = self._recv_packet()
            if packet:
                out.append(packet)
            else:
                break
        return out

    cdef _send_packet_and_recv(self, Packet packet):

        cdef Frame frame

        cdef int res
        with nogil:
            res = lib.avcodec_send_packet(self.ptr, &packet.struct if packet is not None else NULL)
        err_check(res)

        out = []
        while True:
            frame = self._recv_frame()
            if frame:
                out.append(frame)
            else:
                break
        return out

    cdef _prepare_frames_for_encode(self, Frame frame):
        return [frame]

    cdef Frame _alloc_next_frame(self):
        raise NotImplementedError('Base CodecContext cannot decode.')

    cdef _recv_frame(self):

        if not self._next_frame:
            self._next_frame = self._alloc_next_frame()
        cdef Frame frame = self._next_frame

        cdef int res
        with nogil:
            res = lib.avcodec_receive_frame(self.ptr, frame.ptr)

        if res == -EAGAIN or res == lib.AVERROR_EOF:
            return
        err_check(res)

        if not res:
            self._next_frame = None
            return frame

    cdef _recv_packet(self):

        cdef Packet packet = Packet()

        cdef int res
        with nogil:
            res = lib.avcodec_receive_packet(self.ptr, &packet.struct)
        if res == -EAGAIN or res == lib.AVERROR_EOF:
            return
        err_check(res)

        if not res:
            return packet

    cpdef encode(self, Frame frame=None):
        """Encode a list of :class:`.Packet` from the given :class:`.Frame`."""

        if self.ptr.codec_type not in [lib.AVMEDIA_TYPE_VIDEO, lib.AVMEDIA_TYPE_AUDIO]:
            raise NotImplementedError('Encoding is only supported for audio and video.')

        self.open(strict=False)

        frames = self._prepare_frames_for_encode(frame)

        # Assert the frames are in our time base.
        # TODO: Don't mutate time.
        for frame in frames:
            if frame is not None:
                frame._rebase_time(self.ptr.time_base)

        res = []
        for frame in frames:
            for packet in self._send_frame_and_recv(frame):
                self._setup_encoded_packet(packet)
                res.append(packet)
        return res

    cdef _setup_encoded_packet(self, Packet packet):
        # We coerced the frame's time_base into the CodecContext's during encoding,
        # and FFmpeg copied the frame's pts/dts to the packet, so keep track of
        # this time_base in case the frame needs to be muxed to a container with
        # a different time_base.
        #
        # NOTE: if the CodecContext's time_base is altered during encoding, all bets
        # are off!
        packet._time_base = self.ptr.time_base

    cpdef decode(self, Packet packet=None):
        """Decode a list of :class:`.Frame` from the given :class:`.Packet`.

        If the packet is None, the buffers will be flushed. This is useful if
        you do not want the library to automatically re-order frames for you
        (if they are encoded with a codec that has B-frames).

        """

        if not self.codec.ptr:
            raise ValueError('cannot decode unknown codec')

        self.open(strict=False)

        res = []
        for frame in self._send_packet_and_recv(packet):
            if isinstance(frame, Frame):
                self._setup_decoded_frame(frame, packet)
            res.append(frame)
        return res

    cdef _setup_decoded_frame(self, Frame frame, Packet packet):

        # Propagate our manual times.
        # While decoding, frame times are in stream time_base, which PyAV
        # is carrying around.
        # TODO: Somehow get this from the stream so we can not pass the
        # packet here (because flushing packets are bogus).
        frame._time_base = packet._time_base

        frame.index = self.ptr.frame_number - 1

    property name:
        def __get__(self):
            return self.codec.name

    property type:
        def __get__(self):
            return self.codec.type

    property profile:
        def __get__(self):
            if self.ptr.codec and lib.av_get_profile_name(self.ptr.codec, self.ptr.profile):
                return lib.av_get_profile_name(self.ptr.codec, self.ptr.profile)

    property time_base:
        def __get__(self):
            return avrational_to_fraction(&self.ptr.time_base)
        def __set__(self, value):
            to_avrational(value, &self.ptr.time_base)

    property ticks_per_frame:
        def __get__(self):
            return self.ptr.ticks_per_frame

    property bit_rate:
        def __get__(self):
            return self.ptr.bit_rate if self.ptr.bit_rate > 0 else None
        def __set__(self, int value):
            self.ptr.bit_rate = value

    property max_bit_rate:
        def __get__(self):
            if self.ptr.rc_max_rate > 0:
                return self.ptr.rc_max_rate
            else:
                return None

    property bit_rate_tolerance:
        def __get__(self):
            self.ptr.bit_rate_tolerance
        def __set__(self, int value):
            self.ptr.bit_rate_tolerance = value

    # TODO: Does it conceptually make sense that this is on streams, instead
    # of on the container?
    property thread_count:
        def __get__(self):
            return self.ptr.thread_count
        def __set__(self, int value):
            if lib.avcodec_is_open(self.ptr):
                raise RuntimeError("Cannot change thread_count after codec is open.")
            self.ptr.thread_count = value

    property thread_type:
        def __get__(self):
            return _ThreadType.get(self.ptr.thread_type, create=True)
        def __set__(self, value):
            if lib.avcodec_is_open(self.ptr):
                raise RuntimeError("Cannot change thread_type after codec is open.")
            self.ptr.thread_type = _ThreadType[value].value

    property skip_frame:
        def __get__(self):
            return _SkipType._get(self.ptr.skip_frame, create=True)
        def __set__(self, value):
            self.ptr.skip_frame = _SkipType[value].value
