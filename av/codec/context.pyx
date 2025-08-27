cimport libav as lib
from libc.errno cimport EAGAIN
from libc.stdint cimport uint8_t
from libc.string cimport memcpy

from av.bytesource cimport ByteSource, bytesource
from av.codec.codec cimport Codec, wrap_codec
from av.dictionary cimport _Dictionary
from av.error cimport err_check
from av.packet cimport Packet
from av.utils cimport avrational_to_fraction, to_avrational

from enum import Flag, IntEnum

from av.dictionary import Dictionary


cdef object _cinit_sentinel = object()


cdef CodecContext wrap_codec_context(lib.AVCodecContext *c_ctx, const lib.AVCodec *c_codec, HWAccel hwaccel):
    """Build an av.CodecContext for an existing AVCodecContext."""

    cdef CodecContext py_ctx

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

    py_ctx._init(c_ctx, c_codec, hwaccel)

    return py_ctx


class ThreadType(Flag):
    NONE = 0
    FRAME: "Decode more than one frame at once" = lib.FF_THREAD_FRAME
    SLICE: "Decode more than one part of a single frame at once" = lib.FF_THREAD_SLICE
    AUTO: "Decode using both FRAME and SLICE methods." = lib.FF_THREAD_SLICE | lib.FF_THREAD_FRAME

class Flags(IntEnum):
    unaligned = lib.AV_CODEC_FLAG_UNALIGNED
    qscale = lib.AV_CODEC_FLAG_QSCALE
    four_mv = lib.AV_CODEC_FLAG_4MV
    output_corrupt = lib.AV_CODEC_FLAG_OUTPUT_CORRUPT
    qpel = lib.AV_CODEC_FLAG_QPEL
    recon_frame = lib.AV_CODEC_FLAG_RECON_FRAME
    copy_opaque = lib.AV_CODEC_FLAG_COPY_OPAQUE
    frame_duration = lib.AV_CODEC_FLAG_FRAME_DURATION
    pass1 = lib.AV_CODEC_FLAG_PASS1
    pass2 = lib.AV_CODEC_FLAG_PASS2
    loop_filter = lib.AV_CODEC_FLAG_LOOP_FILTER
    gray = lib.AV_CODEC_FLAG_GRAY
    psnr = lib.AV_CODEC_FLAG_PSNR
    interlaced_dct = lib.AV_CODEC_FLAG_INTERLACED_DCT
    low_delay = lib.AV_CODEC_FLAG_LOW_DELAY
    global_header = lib.AV_CODEC_FLAG_GLOBAL_HEADER
    bitexact = lib.AV_CODEC_FLAG_BITEXACT
    ac_pred = lib.AV_CODEC_FLAG_AC_PRED
    interlaced_me = lib.AV_CODEC_FLAG_INTERLACED_ME
    closed_gop = lib.AV_CODEC_FLAG_CLOSED_GOP

class Flags2(IntEnum):
    fast = lib.AV_CODEC_FLAG2_FAST
    no_output = lib.AV_CODEC_FLAG2_NO_OUTPUT
    local_header = lib.AV_CODEC_FLAG2_LOCAL_HEADER
    chunks = lib.AV_CODEC_FLAG2_CHUNKS
    ignore_crop = lib.AV_CODEC_FLAG2_IGNORE_CROP
    show_all = lib.AV_CODEC_FLAG2_SHOW_ALL
    export_mvs = lib.AV_CODEC_FLAG2_EXPORT_MVS
    skip_manual = lib.AV_CODEC_FLAG2_SKIP_MANUAL
    ro_flush_noop = lib.AV_CODEC_FLAG2_RO_FLUSH_NOOP


cdef class CodecContext:
    @staticmethod
    def create(codec, mode=None, hwaccel=None):
        cdef Codec cy_codec = codec if isinstance(codec, Codec) else Codec(codec, mode)
        cdef lib.AVCodecContext *c_ctx = lib.avcodec_alloc_context3(cy_codec.ptr)
        return wrap_codec_context(c_ctx, cy_codec.ptr, hwaccel)

    def __cinit__(self, sentinel=None, *args, **kwargs):
        if sentinel is not _cinit_sentinel:
            raise RuntimeError("Cannot instantiate CodecContext")

        self.options = {}
        self.stream_index = -1  # This is set by the container immediately.
        self.is_open = False

    cdef _init(self, lib.AVCodecContext *ptr, const lib.AVCodec *codec, HWAccel hwaccel):
        self.ptr = ptr
        if self.ptr.codec and codec and self.ptr.codec != codec:
            raise RuntimeError("Wrapping CodecContext with mismatched codec.")
        self.codec = wrap_codec(codec if codec != NULL else self.ptr.codec)
        self.hwaccel = hwaccel

        # Set reasonable threading defaults.
        self.ptr.thread_count = 0  # use as many threads as there are CPUs.
        self.ptr.thread_type = 0x02  # thread within a frame. Does not change the API.

    @property
    def flags(self):
        """
        Get and set the flags bitmask of CodecContext.

        :rtype: int
        """
        return self.ptr.flags

    @flags.setter
    def flags(self, int value):
        self.ptr.flags = value

    @property
    def qscale(self):
        """
        Use fixed qscale.

        :rtype: bool
        """
        return bool(self.ptr.flags & lib.AV_CODEC_FLAG_QSCALE)

    @qscale.setter
    def qscale(self, value):
        if value:
            self.ptr.flags |= lib.AV_CODEC_FLAG_QSCALE
        else:
            self.ptr.flags &= ~lib.AV_CODEC_FLAG_QSCALE

    @property
    def copy_opaque(self):
        return bool(self.ptr.flags & lib.AV_CODEC_FLAG_COPY_OPAQUE)

    @copy_opaque.setter
    def copy_opaque(self, value):
        if value:
            self.ptr.flags |= lib.AV_CODEC_FLAG_COPY_OPAQUE
        else:
            self.ptr.flags &= ~lib.AV_CODEC_FLAG_COPY_OPAQUE

    @property
    def flags2(self):
        """
        Get and set the flags2 bitmask of CodecContext.

        :rtype: int
        """
        return self.ptr.flags2

    @flags2.setter
    def flags2(self, int value):
        self.ptr.flags2 = value

    @property
    def extradata(self):
        if self.ptr is NULL:
            return None
        if self.ptr.extradata_size > 0:
            return <bytes>(<uint8_t*>self.ptr.extradata)[:self.ptr.extradata_size]
        return None

    @extradata.setter
    def extradata(self, data):
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

    @property
    def extradata_size(self):
        return self.ptr.extradata_size

    @property
    def is_encoder(self):
        if self.ptr is NULL:
            return False
        return lib.av_codec_is_encoder(self.ptr.codec)

    @property
    def is_decoder(self):
        if self.ptr is NULL:
            return False
        return lib.av_codec_is_decoder(self.ptr.codec)

    cpdef open(self, bint strict=True):
        if self.is_open:
            if strict:
                raise ValueError("CodecContext is already open.")
            return

        cdef _Dictionary options = Dictionary()
        options.update(self.options or {})

        if not self.ptr.time_base.num and self.is_encoder:
            if self.type == "video":
                self.ptr.time_base.num = self.ptr.framerate.den or 1
                self.ptr.time_base.den = self.ptr.framerate.num or lib.AV_TIME_BASE
            elif self.type == "audio":
                self.ptr.time_base.num = 1
                self.ptr.time_base.den = self.ptr.sample_rate
            else:
                self.ptr.time_base.num = 1
                self.ptr.time_base.den = lib.AV_TIME_BASE

        err_check(lib.avcodec_open2(self.ptr, self.codec.ptr, &options.ptr), "avcodec_open2(" + self.codec.name + ")")
        self.is_open = True
        self.options = dict(options)

    def __dealloc__(self):
        if self.ptr and self.extradata_set:
            lib.av_freep(&self.ptr.extradata)
        if self.ptr:
            lib.avcodec_free_context(&self.ptr)
        if self.parser:
            lib.av_parser_close(self.parser)

    def __repr__(self):
        _type = self.type or "<notype>"
        name = self.name or "<nocodec>"
        return f"<av.{self.__class__.__name__} {_type}/{name} at 0x{id(self):x}>"

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
                raise ValueError(f"No parser for {self.codec.name}")

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
                break

        return packets

    @property
    def is_hwaccel(self):
        """
        Returns ``True`` if this codec context is hardware accelerated, ``False`` otherwise.
        """
        return self.hwaccel_ctx is not None

    def _send_frame_and_recv(self, Frame frame):
        cdef Packet packet

        cdef int res
        with nogil:
            res = lib.avcodec_send_frame(self.ptr, frame.ptr if frame is not None else NULL)
        err_check(res, "avcodec_send_frame()")

        packet = self._recv_packet()
        while packet:
            yield packet
            packet = self._recv_packet()

    cdef _send_packet_and_recv(self, Packet packet):
        cdef Frame frame

        cdef int res
        with nogil:
            res = lib.avcodec_send_packet(self.ptr, packet.ptr if packet is not None else NULL)
        err_check(res, "avcodec_send_packet()")

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
        raise NotImplementedError("Base CodecContext cannot decode.")

    cdef _recv_frame(self):
        if not self._next_frame:
            self._next_frame = self._alloc_next_frame()
        cdef Frame frame = self._next_frame

        cdef int res
        with nogil:
            res = lib.avcodec_receive_frame(self.ptr, frame.ptr)

        if res == -EAGAIN or res == lib.AVERROR_EOF:
            return
        err_check(res, "avcodec_receive_frame()")

        frame = self._transfer_hwframe(frame)

        if not res:
            self._next_frame = None
            return frame

    cdef _transfer_hwframe(self, Frame frame):
        return frame

    cdef _recv_packet(self):
        cdef Packet packet = Packet()

        cdef int res
        with nogil:
            res = lib.avcodec_receive_packet(self.ptr, packet.ptr)
        if res == -EAGAIN or res == lib.AVERROR_EOF:
            return
        err_check(res, "avcodec_receive_packet()")

        if not res:
            return packet

    cdef _prepare_and_time_rebase_frames_for_encode(self, Frame frame):
        if self.ptr.codec_type not in [lib.AVMEDIA_TYPE_VIDEO, lib.AVMEDIA_TYPE_AUDIO]:
            raise NotImplementedError("Encoding is only supported for audio and video.")

        self.open(strict=False)

        frames = self._prepare_frames_for_encode(frame)

        # Assert the frames are in our time base.
        # TODO: Don't mutate time.
        for frame in frames:
            if frame is not None:
                frame._rebase_time(self.ptr.time_base)

        return frames

    cpdef encode(self, Frame frame=None):
        """Encode a list of :class:`.Packet` from the given :class:`.Frame`."""
        res = []
        for frame in self._prepare_and_time_rebase_frames_for_encode(frame):
            for packet in self._send_frame_and_recv(frame):
                self._setup_encoded_packet(packet)
                res.append(packet)
        return res

    def encode_lazy(self, Frame frame=None):
        for frame in self._prepare_and_time_rebase_frames_for_encode(frame):
            for packet in self._send_frame_and_recv(frame):
                self._setup_encoded_packet(packet)
                yield packet

    cdef _setup_encoded_packet(self, Packet packet):
        # We coerced the frame's time_base into the CodecContext's during encoding,
        # and FFmpeg copied the frame's pts/dts to the packet, so keep track of
        # this time_base in case the frame needs to be muxed to a container with
        # a different time_base.
        #
        # NOTE: if the CodecContext's time_base is altered during encoding, all bets
        # are off!
        packet.ptr.time_base = self.ptr.time_base

    cpdef decode(self, Packet packet=None):
        """Decode a list of :class:`.Frame` from the given :class:`.Packet`.

        If the packet is None, the buffers will be flushed. This is useful if
        you do not want the library to automatically re-order frames for you
        (if they are encoded with a codec that has B-frames).

        """

        if not self.codec.ptr:
            raise ValueError("cannot decode unknown codec")

        self.open(strict=False)

        res = []
        for frame in self._send_packet_and_recv(packet):
            if isinstance(frame, Frame):
                self._setup_decoded_frame(frame, packet)
            res.append(frame)
        return res

    cpdef flush_buffers(self):
        """Reset the internal codec state and discard all internal buffers.

        Should be called before you start decoding from a new position e.g.
        when seeking or when switching to a different stream.

        """
        if self.is_open:
            with nogil:
                lib.avcodec_flush_buffers(self.ptr)

    cdef _setup_decoded_frame(self, Frame frame, Packet packet):
        # Propagate our manual times.
        # While decoding, frame times are in stream time_base, which PyAV
        # is carrying around.
        # TODO: Somehow get this from the stream so we can not pass the
        # packet here (because flushing packets are bogus).
        if packet is not None:
            frame._time_base = packet.ptr.time_base

    @property
    def name(self):
        return self.codec.name

    @property
    def type(self):
        return self.codec.type

    @property
    def profiles(self):
        """
        List the available profiles for this stream.

        :type: list[str]
        """
        ret = []
        if not self.ptr.codec or not self.codec.desc or not self.codec.desc.profiles:
            return ret

        # Profiles are always listed in the codec descriptor, but not necessarily in
        # the codec itself. So use the descriptor here.
        desc = self.codec.desc
        cdef int i = 0
        while desc.profiles[i].profile != lib.AV_PROFILE_UNKNOWN: 
            ret.append(desc.profiles[i].name)
            i += 1

        return ret

    @property
    def profile(self):
        if not self.ptr.codec or not self.codec.desc or not self.codec.desc.profiles:
            return

        # Profiles are always listed in the codec descriptor, but not necessarily in
        # the codec itself. So use the descriptor here.
        desc = self.codec.desc
        cdef int i = 0
        while desc.profiles[i].profile != lib.AV_PROFILE_UNKNOWN: 
            if desc.profiles[i].profile == self.ptr.profile:
                return desc.profiles[i].name
            i += 1

    @profile.setter
    def profile(self, value):
        if not self.codec or not self.codec.desc or not self.codec.desc.profiles:
            return

        # Profiles are always listed in the codec descriptor, but not necessarily in
        # the codec itself. So use the descriptor here.
        desc = self.codec.desc
        cdef int i = 0
        while desc.profiles[i].profile != lib.AV_PROFILE_UNKNOWN:
            if desc.profiles[i].name == value:
                self.ptr.profile = desc.profiles[i].profile
                return
            i += 1

    @property
    def time_base(self):
        if self.is_decoder:
            raise RuntimeError("Cannot access 'time_base' as a decoder")
        return avrational_to_fraction(&self.ptr.time_base)

    @time_base.setter
    def time_base(self, value):
        if self.is_decoder:
            raise RuntimeError("Cannot access 'time_base' as a decoder")
        to_avrational(value, &self.ptr.time_base)

    @property
    def codec_tag(self):
        return self.ptr.codec_tag.to_bytes(4, byteorder="little", signed=False).decode(
            encoding="ascii")

    @codec_tag.setter
    def codec_tag(self, value):
        if isinstance(value, str) and len(value) == 4:
            self.ptr.codec_tag = int.from_bytes(value.encode(encoding="ascii"),
                                                byteorder="little", signed=False)
        else:
            raise ValueError("Codec tag should be a 4 character string.")

    @property
    def bit_rate(self):
        return self.ptr.bit_rate if self.ptr.bit_rate > 0 else None

    @bit_rate.setter
    def bit_rate(self, int value):
        self.ptr.bit_rate = value

    @property
    def max_bit_rate(self):
        if self.ptr.rc_max_rate > 0:
            return self.ptr.rc_max_rate
        else:
            return None

    @property
    def bit_rate_tolerance(self):
        self.ptr.bit_rate_tolerance

    @bit_rate_tolerance.setter
    def bit_rate_tolerance(self, int value):
        self.ptr.bit_rate_tolerance = value

    @property
    def thread_count(self):
        """How many threads to use; 0 means auto.

        Wraps :ffmpeg:`AVCodecContext.thread_count`.

        """
        return self.ptr.thread_count

    @thread_count.setter
    def thread_count(self, int value):
        if self.is_open:
            raise RuntimeError("Cannot change thread_count after codec is open.")
        self.ptr.thread_count = value

    @property
    def thread_type(self):
        """One of :class:`.ThreadType`.

        Wraps :ffmpeg:`AVCodecContext.thread_type`.

        """
        return ThreadType(self.ptr.thread_type)

    @thread_type.setter
    def thread_type(self, value):
        if self.is_open:
            raise RuntimeError("Cannot change thread_type after codec is open.")
        if type(value) is int:
            self.ptr.thread_type = value
        elif type(value) is str:
            self.ptr.thread_type = ThreadType[value].value
        else:
            self.ptr.thread_type = value.value

    @property
    def skip_frame(self):
        """Returns one of the following str literals:

        "NONE" Discard nothing
        "DEFAULT" Discard useless packets like 0 size packets in AVI
        "NONREF" Discard all non reference
        "BIDIR" Discard all bidirectional frames
        "NONINTRA" Discard all non intra frames
        "NONKEY Discard all frames except keyframes
        "ALL" Discard all

        Wraps :ffmpeg:`AVCodecContext.skip_frame`.
        """
        value = self.ptr.skip_frame
        if value == lib.AVDISCARD_NONE:
            return "NONE"
        if value == lib.AVDISCARD_DEFAULT:
            return "DEFAULT"
        if value == lib.AVDISCARD_NONREF:
            return "NONREF"
        if value == lib.AVDISCARD_BIDIR:
            return "BIDIR"
        if value == lib.AVDISCARD_NONINTRA:
            return "NONINTRA"
        if value == lib.AVDISCARD_NONKEY:
            return "NONKEY"
        if value == lib.AVDISCARD_ALL:
            return "ALL"
        return f"{value}"

    @skip_frame.setter
    def skip_frame(self, value):
        if value == "NONE":
            self.ptr.skip_frame = lib.AVDISCARD_NONE
        elif value == "DEFAULT":
            self.ptr.skip_frame = lib.AVDISCARD_DEFAULT
        elif value == "NONREF":
            self.ptr.skip_frame = lib.AVDISCARD_NONREF
        elif value == "BIDIR":
            self.ptr.skip_frame = lib.AVDISCARD_BIDIR
        elif value == "NONINTRA":
            self.ptr.skip_frame = lib.AVDISCARD_NONINTRA
        elif value == "NONKEY":
            self.ptr.skip_frame = lib.AVDISCARD_NONKEY
        elif value == "ALL":
            self.ptr.skip_frame = lib.AVDISCARD_ALL
        else:
            raise ValueError("Invalid skip_frame type")

    @property
    def delay(self):
        """Codec delay.

        Wraps :ffmpeg:`AVCodecContext.delay`.

        """
        return self.ptr.delay
