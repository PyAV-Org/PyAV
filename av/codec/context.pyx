import warnings

from libc.errno cimport EAGAIN
from libc.stdint cimport int64_t, uint8_t
from libc.string cimport memcpy
cimport libav as lib

from av.bytesource cimport ByteSource, bytesource
from av.codec.codec cimport Codec, wrap_codec
from av.dictionary cimport _Dictionary
from av.enum cimport define_enum
from av.error cimport err_check
from av.packet cimport Packet
from av.utils cimport avrational_to_fraction, to_avrational

from av.deprecation import AVDeprecationWarning
from av.dictionary import Dictionary


cdef object _cinit_sentinel = object()


cdef CodecContext wrap_codec_context(lib.AVCodecContext *c_ctx, const lib.AVCodec *c_codec):
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

    py_ctx._init(c_ctx, c_codec)

    return py_ctx


ThreadType = define_enum('ThreadType', __name__, (
    ('NONE', 0),
    ('FRAME', lib.FF_THREAD_FRAME,
        """Decode more than one frame at once"""),
    ('SLICE', lib.FF_THREAD_SLICE,
        """Decode more than one part of a single frame at once"""),
    ('AUTO', lib.FF_THREAD_SLICE | lib.FF_THREAD_FRAME,
        """Decode using both FRAME and SLICE methods."""),
), is_flags=True)

SkipType = define_enum('SkipType', __name__, (
    ('NONE', lib.AVDISCARD_NONE,
        """Discard nothing"""),
    ('DEFAULT', lib.AVDISCARD_DEFAULT,
        """Discard useless packets like 0 size packets in AVI"""),
    ('NONREF', lib.AVDISCARD_NONREF,
        """Discard all non reference"""),
    ('BIDIR', lib.AVDISCARD_BIDIR,
        """Discard all bidirectional frames"""),
    ('NONINTRA', lib.AVDISCARD_NONINTRA,
        """Discard all non intra frames"""),
    ('NONKEY', lib.AVDISCARD_NONKEY,
        """Discard all frames except keyframes"""),
    ('ALL', lib.AVDISCARD_ALL,
        """Discard all"""),
))

Flags = define_enum('Flags', __name__, (
    ('NONE', 0),
    ('UNALIGNED', lib.AV_CODEC_FLAG_UNALIGNED,
        """Allow decoders to produce frames with data planes that are not aligned
        to CPU requirements (e.g. due to cropping)."""),
    ('QSCALE', lib.AV_CODEC_FLAG_QSCALE,
        """Use fixed qscale."""),
    ('4MV', lib.AV_CODEC_FLAG_4MV,
        """4 MV per MB allowed / advanced prediction for H.263."""),
    ('OUTPUT_CORRUPT', lib.AV_CODEC_FLAG_OUTPUT_CORRUPT,
        """Output even those frames that might be corrupted."""),
    ('QPEL', lib.AV_CODEC_FLAG_QPEL,
        """Use qpel MC."""),
    ('DROPCHANGED', 1 << 5,
        """Don't output frames whose parameters differ from first
        decoded frame in stream."""),
    ('PASS1', lib.AV_CODEC_FLAG_PASS1,
        """Use internal 2pass ratecontrol in first pass mode."""),
    ('PASS2', lib.AV_CODEC_FLAG_PASS2,
        """Use internal 2pass ratecontrol in second pass mode."""),
    ('LOOP_FILTER', lib.AV_CODEC_FLAG_LOOP_FILTER,
        """loop filter."""),
    ('GRAY', lib.AV_CODEC_FLAG_GRAY,
        """Only decode/encode grayscale."""),
    ('PSNR', lib.AV_CODEC_FLAG_PSNR,
        """error[?] variables will be set during encoding."""),
    ('INTERLACED_DCT', lib.AV_CODEC_FLAG_INTERLACED_DCT,
        """Use interlaced DCT."""),
    ('LOW_DELAY', lib.AV_CODEC_FLAG_LOW_DELAY,
        """Force low delay."""),
    ('GLOBAL_HEADER', lib.AV_CODEC_FLAG_GLOBAL_HEADER,
        """Place global headers in extradata instead of every keyframe."""),
    ('BITEXACT', lib.AV_CODEC_FLAG_BITEXACT,
        """Use only bitexact stuff (except (I)DCT)."""),
    ('AC_PRED', lib.AV_CODEC_FLAG_AC_PRED,
        """H.263 advanced intra coding / MPEG-4 AC prediction"""),
    ('INTERLACED_ME', lib.AV_CODEC_FLAG_INTERLACED_ME,
        """Interlaced motion estimation"""),
    ('CLOSED_GOP', lib.AV_CODEC_FLAG_CLOSED_GOP),
), is_flags=True)

Flags2 = define_enum('Flags2', __name__, (
    ('NONE', 0),
    ('FAST', lib.AV_CODEC_FLAG2_FAST,
        """Allow non spec compliant speedup tricks."""),
    ('NO_OUTPUT', lib.AV_CODEC_FLAG2_NO_OUTPUT,
        """Skip bitstream encoding."""),
    ('LOCAL_HEADER', lib.AV_CODEC_FLAG2_LOCAL_HEADER,
        """Place global headers at every keyframe instead of in extradata."""),
    ('CHUNKS', lib.AV_CODEC_FLAG2_CHUNKS,
        """Input bitstream might be truncated at a packet boundaries
        instead of only at frame boundaries."""),
    ('IGNORE_CROP', lib.AV_CODEC_FLAG2_IGNORE_CROP,
        """Discard cropping information from SPS."""),
    ('SHOW_ALL', lib.AV_CODEC_FLAG2_SHOW_ALL,
        """Show all frames before the first keyframe"""),
    ('EXPORT_MVS', lib.AV_CODEC_FLAG2_EXPORT_MVS,
        """Export motion vectors through frame side data"""),
    ('SKIP_MANUAL', lib.AV_CODEC_FLAG2_SKIP_MANUAL,
        """Do not skip samples and export skip information as frame side data"""),
    ('RO_FLUSH_NOOP', lib.AV_CODEC_FLAG2_RO_FLUSH_NOOP,
        """Do not reset ASS ReadOrder field on flush (subtitles decoding)"""),
), is_flags=True)


cdef class CodecContext(object):

    @staticmethod
    def create(codec, mode=None):
        cdef Codec cy_codec = codec if isinstance(codec, Codec) else Codec(codec, mode)
        cdef lib.AVCodecContext *c_ctx = lib.avcodec_alloc_context3(cy_codec.ptr)
        return wrap_codec_context(c_ctx, cy_codec.ptr)

    def __cinit__(self, sentinel=None, *args, **kwargs):
        if sentinel is not _cinit_sentinel:
            raise RuntimeError('Cannot instantiate CodecContext')

        self.options = {}
        self.stream_index = -1  # This is set by the container immediately.

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

    def _get_flags(self):
        return self.ptr.flags

    def _set_flags(self, value):
        self.ptr.flags = value

    flags = Flags.property(
        _get_flags,
        _set_flags,
        """Flag property of :class:`.Flags`."""
    )

    unaligned = flags.flag_property('UNALIGNED')
    qscale = flags.flag_property('QSCALE')
    four_mv = flags.flag_property('4MV')
    output_corrupt = flags.flag_property('OUTPUT_CORRUPT')
    qpel = flags.flag_property('QPEL')
    drop_changed = flags.flag_property('DROPCHANGED')
    pass1 = flags.flag_property('PASS1')
    pass2 = flags.flag_property('PASS2')
    loop_filter = flags.flag_property('LOOP_FILTER')
    gray = flags.flag_property('GRAY')
    psnr = flags.flag_property('PSNR')
    interlaced_dct = flags.flag_property('INTERLACED_DCT')
    low_delay = flags.flag_property('LOW_DELAY')
    global_header = flags.flag_property('GLOBAL_HEADER')
    bitexact = flags.flag_property('BITEXACT')
    ac_pred = flags.flag_property('AC_PRED')
    interlaced_me = flags.flag_property('INTERLACED_ME')
    closed_gop = flags.flag_property('CLOSED_GOP')

    def _get_flags2(self):
        return self.ptr.flags2

    def _set_flags2(self, value):
        self.ptr.flags2 = value

    flags2 = Flags2.property(
        _get_flags2,
        _set_flags2,
        """Flag property of :class:`.Flags2`."""
    )

    fast = flags2.flag_property('FAST')
    no_output = flags2.flag_property('NO_OUTPUT')
    local_header = flags2.flag_property('LOCAL_HEADER')
    chunks = flags2.flag_property('CHUNKS')
    ignore_crop = flags2.flag_property('IGNORE_CROP')
    show_all = flags2.flag_property('SHOW_ALL')
    export_mvs = flags2.flag_property('EXPORT_MVS')
    skip_manual = flags2.flag_property('SKIP_MANUAL')
    ro_flush_noop = flags2.flag_property('RO_FLUSH_NOOP')

    property extradata:
        def __get__(self):
            if self.ptr.extradata_size > 0:
                return <bytes>(<uint8_t*>self.ptr.extradata)[:self.ptr.extradata_size]
            else:
                return None

        def __set__(self, data):
            if not self.is_decoder:
                raise ValueError("Can only set extradata for decoders.")

            if data is None:
                lib.av_freep(&self.ptr.extradata)
                self.ptr.extradata_size = 0
            else:
                source = bytesource(data)
                self.ptr.extradata = <uint8_t*>lib.av_realloc(self.ptr.extradata, source.length + lib.AV_INPUT_BUFFER_PADDING_SIZE)
                if not self.ptr.extradata:
                    raise MemoryError("Cannot allocate extradata")
                memcpy(self.ptr.extradata, source.ptr, source.length)
                self.ptr.extradata_size = source.length
            self.extradata_set = True

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

        # Assert we have a time_base for encoders.
        if not self.ptr.time_base.num and self.is_encoder:
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
        if self.ptr and self.extradata_set:
            lib.av_freep(&self.ptr.extradata)
        if self.ptr:
            lib.avcodec_close(self.ptr)
            lib.avcodec_free_context(&self.ptr)
        if self.parser:
            lib.av_parser_close(self.parser)

    def __repr__(self):
        return '<av.%s %s/%s at 0x%x>' % (
            self.__class__.__name__,
            self.type or '<notype>',
            self.name or '<nocodec>',
            id(self),
        )

    def parse(self, raw_input=None):
        """Split up a byte stream into list of :class:`.Packet`.

        This is only effectively splitting up a byte stream, and does no
        actual interpretation of the data.

        It will return all packets that are fully contained within the given
        input, and will buffer partial packets until they are complete.

        :param ByteSource raw_input: A chunk of a byte-stream to process.
            Anything that can be turned into a :class:`.ByteSource` is fine.
            ``None`` or empty inputs will flush the parser's buffers.

        :return: ``list`` of :class:`.Packet` newly available.

        """

        if not self.parser:
            self.parser = lib.av_parser_init(self.codec.ptr.id)
            if not self.parser:
                raise ValueError('No parser for %s' % self.codec.name)

        cdef ByteSource source = bytesource(raw_input, allow_none=True)

        cdef unsigned char *in_data = source.ptr if source is not None else NULL
        cdef int in_size = source.length if source is not None else 0

        cdef unsigned char *out_data
        cdef int out_size
        cdef int consumed
        cdef Packet packet = None

        packets = []

        while True:

            with nogil:
                consumed = lib.av_parser_parse2(
                    self.parser,
                    self.ptr,
                    &out_data, &out_size,
                    in_data, in_size,
                    lib.AV_NOPTS_VALUE, lib.AV_NOPTS_VALUE,
                    0
                )
            err_check(consumed)

            if out_size:

                # We copy the data immediately, as we have yet to figure out
                # the expected lifetime of the buffer we get back. All of the
                # examples decode it immediately.
                #
                # We've also tried:
                #   packet = Packet()
                #   packet.data = out_data
                #   packet.size = out_size
                #   packet.source = source
                #
                # ... but this results in corruption.

                packet = Packet(out_size)
                memcpy(packet.ptr.data, out_data, out_size)

                packets.append(packet)

            if not in_size:
                # This was a flush. Only one packet should ever be returned.
                break

            in_data += consumed
            in_size -= consumed

            if not in_size:
                # Aaaand now we're done.
                break

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
            res = lib.avcodec_send_packet(self.ptr, packet.ptr if packet is not None else NULL)
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
            res = lib.avcodec_receive_packet(self.ptr, packet.ptr)
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
            if self.is_decoder:
                warnings.warn(
                    "Using CodecContext.time_base for decoders is deprecated.",
                    AVDeprecationWarning
                )
            return avrational_to_fraction(&self.ptr.time_base)

        def __set__(self, value):
            if self.is_decoder:
                warnings.warn(
                    "Using CodecContext.time_base for decoders is deprecated.",
                    AVDeprecationWarning
                )
            to_avrational(value, &self.ptr.time_base)

    property codec_tag:
        def __get__(self):
            return self.ptr.codec_tag.to_bytes(4, byteorder="little", signed=False).decode(
                encoding="ascii")

        def __set__(self, value):
            if isinstance(value, str) and len(value) == 4:
                self.ptr.codec_tag = int.from_bytes(value.encode(encoding="ascii"),
                                                    byteorder="little", signed=False)
            else:
                raise ValueError("Codec tag should be a 4 character string.")

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

    property thread_count:
        """How many threads to use; 0 means auto.

        Wraps :ffmpeg:`AVCodecContext.thread_count`.

        """

        def __get__(self):
            return self.ptr.thread_count

        def __set__(self, int value):
            if lib.avcodec_is_open(self.ptr):
                raise RuntimeError("Cannot change thread_count after codec is open.")
            self.ptr.thread_count = value

    property thread_type:
        """One of :class:`.ThreadType`.

        Wraps :ffmpeg:`AVCodecContext.thread_type`.

        """

        def __get__(self):
            return ThreadType.get(self.ptr.thread_type, create=True)

        def __set__(self, value):
            if lib.avcodec_is_open(self.ptr):
                raise RuntimeError("Cannot change thread_type after codec is open.")
            self.ptr.thread_type = ThreadType[value].value

    property skip_frame:
        """One of :class:`.SkipType`.

        Wraps ffmpeg:`AVCodecContext.skip_frame`.

        """

        def __get__(self):
            return SkipType._get(self.ptr.skip_frame, create=True)

        def __set__(self, value):
            self.ptr.skip_frame = SkipType[value].value
