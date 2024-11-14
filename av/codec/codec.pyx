from av.audio.format cimport get_audio_format
from av.descriptor cimport wrap_avclass
from av.enum cimport define_enum
from av.utils cimport avrational_to_fraction
from av.video.format cimport get_video_format

from enum import Flag


cdef object _cinit_sentinel = object()

cdef Codec wrap_codec(const lib.AVCodec *ptr):
    cdef Codec codec = Codec(_cinit_sentinel)
    codec.ptr = ptr
    codec.is_encoder = lib.av_codec_is_encoder(ptr)
    codec._init()
    return codec

class Properties(Flag):
    NONE = 0
    INTRA_ONLY = lib.AV_CODEC_PROP_INTRA_ONLY
    LOSSY = lib.AV_CODEC_PROP_LOSSY
    LOSSLESS = lib.AV_CODEC_PROP_LOSSLESS
    REORDER = lib.AV_CODEC_PROP_REORDER
    BITMAP_SUB = lib.AV_CODEC_PROP_BITMAP_SUB
    TEXT_SUB = lib.AV_CODEC_PROP_TEXT_SUB

Capabilities = define_enum("Capabilities", "av.codec", (
    ("NONE", 0),
    ("DRAW_HORIZ_BAND", lib.AV_CODEC_CAP_DRAW_HORIZ_BAND,
        """Decoder can use draw_horiz_band callback."""),
    ("DR1", lib.AV_CODEC_CAP_DR1,
        """Codec uses get_buffer() for allocating buffers and supports custom allocators.
        If not set, it might not use get_buffer() at all or use operations that
        assume the buffer was allocated by avcodec_default_get_buffer."""),
    ("HWACCEL", 1 << 4),
    ("DELAY", lib.AV_CODEC_CAP_DELAY,
        """Encoder or decoder requires flushing with NULL input at the end in order to
        give the complete and correct output.

        NOTE: If this flag is not set, the codec is guaranteed to never be fed with
              with NULL data. The user can still send NULL data to the public encode
              or decode function, but libavcodec will not pass it along to the codec
              unless this flag is set.

        Decoders:
        The decoder has a non-zero delay and needs to be fed with avpkt->data=NULL,
        avpkt->size=0 at the end to get the delayed data until the decoder no longer
        returns frames.

        Encoders:
        The encoder needs to be fed with NULL data at the end of encoding until the
        encoder no longer returns data.

        NOTE: For encoders implementing the AVCodec.encode2() function, setting this
              flag also means that the encoder must set the pts and duration for
              each output packet. If this flag is not set, the pts and duration will
              be determined by libavcodec from the input frame."""),
    ("SMALL_LAST_FRAME", lib.AV_CODEC_CAP_SMALL_LAST_FRAME,
        """Codec can be fed a final frame with a smaller size.
        This can be used to prevent truncation of the last audio samples."""),
    ("HWACCEL_VDPAU", 1 << 7),
    ("SUBFRAMES", lib.AV_CODEC_CAP_SUBFRAMES,
        """Codec can output multiple frames per AVPacket
        Normally demuxers return one frame at a time, demuxers which do not do
        are connected to a parser to split what they return into proper frames.
        This flag is reserved to the very rare category of codecs which have a
        bitstream that cannot be split into frames without timeconsuming
        operations like full decoding. Demuxers carrying such bitstreams thus
        may return multiple frames in a packet. This has many disadvantages like
        prohibiting stream copy in many cases thus it should only be considered
        as a last resort."""),
    ("EXPERIMENTAL", lib.AV_CODEC_CAP_EXPERIMENTAL,
        """Codec is experimental and is thus avoided in favor of non experimental
        encoders"""),
    ("CHANNEL_CONF", lib.AV_CODEC_CAP_CHANNEL_CONF,
        """Codec should fill in channel configuration and samplerate instead of container"""),
    ("NEG_LINESIZES", 1 << 11),
    ("FRAME_THREADS", lib.AV_CODEC_CAP_FRAME_THREADS,
        """Codec supports frame-level multithreading""",),
    ("SLICE_THREADS", lib.AV_CODEC_CAP_SLICE_THREADS,
        """Codec supports slice-based (or partition-based) multithreading."""),
    ("PARAM_CHANGE", lib.AV_CODEC_CAP_PARAM_CHANGE,
        """Codec supports changed parameters at any point."""),
    ("AUTO_THREADS", lib.AV_CODEC_CAP_OTHER_THREADS,
        """Codec supports multithreading through a method other than slice- or
        frame-level multithreading. Typically this marks wrappers around
        multithreading-capable external libraries."""),
    ("VARIABLE_FRAME_SIZE", lib.AV_CODEC_CAP_VARIABLE_FRAME_SIZE,
        """Audio encoder supports receiving a different number of samples in each call."""),
    ("AVOID_PROBING", lib.AV_CODEC_CAP_AVOID_PROBING,
        """Decoder is not a preferred choice for probing.
        This indicates that the decoder is not a good choice for probing.
        It could for example be an expensive to spin up hardware decoder,
        or it could simply not provide a lot of useful information about
        the stream.
        A decoder marked with this flag should only be used as last resort
        choice for probing."""),
    ("HARDWARE", lib.AV_CODEC_CAP_HARDWARE,
        """Codec is backed by a hardware implementation. Typically used to
        identify a non-hwaccel hardware decoder. For information about hwaccels, use
        avcodec_get_hw_config() instead."""),
    ("HYBRID", lib.AV_CODEC_CAP_HYBRID,
        """Codec is potentially backed by a hardware implementation, but not
        necessarily. This is used instead of AV_CODEC_CAP_HARDWARE, if the
        implementation provides some sort of internal fallback."""),
    ("ENCODER_REORDERED_OPAQUE", 1 << 20,  # lib.AV_CODEC_CAP_ENCODER_REORDERED_OPAQUE,  # FFmpeg 4.2
        """This codec takes the reordered_opaque field from input AVFrames
        and returns it in the corresponding field in AVCodecContext after
        encoding."""),
    ("ENCODER_FLUSH", 1 << 21,  # lib.AV_CODEC_CAP_ENCODER_FLUSH  # FFmpeg 4.3
        """This encoder can be flushed using avcodec_flush_buffers(). If this
        flag is not set, the encoder must be closed and reopened to ensure that
        no frames remain pending."""),
), is_flags=True)


class UnknownCodecError(ValueError):
    pass


cdef class Codec:
    """Codec(name, mode='r')

    :param str name: The codec name.
    :param str mode: ``'r'`` for decoding or ``'w'`` for encoding.

    This object exposes information about an available codec, and an avenue to
    create a :class:`.CodecContext` to encode/decode directly.

    ::

        >>> codec = Codec('mpeg4', 'r')
        >>> codec.name
        'mpeg4'
        >>> codec.type
        'video'
        >>> codec.is_encoder
        False

    """

    def __cinit__(self, name, mode="r"):
        if name is _cinit_sentinel:
            return

        if mode == "w":
            self.ptr = lib.avcodec_find_encoder_by_name(name)
            if not self.ptr:
                self.desc = lib.avcodec_descriptor_get_by_name(name)
                if self.desc:
                    self.ptr = lib.avcodec_find_encoder(self.desc.id)

        elif mode == "r":
            self.ptr = lib.avcodec_find_decoder_by_name(name)
            if not self.ptr:
                self.desc = lib.avcodec_descriptor_get_by_name(name)
                if self.desc:
                    self.ptr = lib.avcodec_find_decoder(self.desc.id)

        else:
            raise ValueError('Invalid mode; must be "r" or "w".', mode)

        self._init(name)

        # Sanity check.
        if (mode == "w") != self.is_encoder:
            raise RuntimeError("Found codec does not match mode.", name, mode)

    cdef _init(self, name=None):
        if not self.ptr:
            raise UnknownCodecError(name)

        if not self.desc:
            self.desc = lib.avcodec_descriptor_get(self.ptr.id)
            if not self.desc:
                raise RuntimeError("No codec descriptor for %r." % name)

        self.is_encoder = lib.av_codec_is_encoder(self.ptr)

        # Sanity check.
        if self.is_encoder and lib.av_codec_is_decoder(self.ptr):
            raise RuntimeError("%s is both encoder and decoder.")

    def create(self, str kind = None):
        """Create a :class:`.CodecContext` for this codec.

        :param str kind: Gives a hint to static type checkers for what exact CodecContext is used.
        """
        from .context import CodecContext
        return CodecContext.create(self)

    @property
    def is_decoder(self):
        return not self.is_encoder

    @property
    def descriptor(self): return wrap_avclass(self.ptr.priv_class)

    @property
    def name(self): return self.ptr.name or ""

    @property
    def long_name(self): return self.ptr.long_name or ""

    @property
    def type(self):
        """
        The media type of this codec.

        E.g: ``'audio'``, ``'video'``, ``'subtitle'``.

        """
        return lib.av_get_media_type_string(self.ptr.type)

    @property
    def id(self): return self.ptr.id

    @property
    def frame_rates(self):
        """A list of supported frame rates (:class:`fractions.Fraction`), or ``None``."""
        if not self.ptr.supported_framerates:
            return

        ret = []
        cdef int i = 0
        while self.ptr.supported_framerates[i].denum:
            ret.append(avrational_to_fraction(&self.ptr.supported_framerates[i]))
            i += 1
        return ret

    @property
    def audio_rates(self):
        """A list of supported audio sample rates (``int``), or ``None``."""
        if not self.ptr.supported_samplerates:
            return

        ret = []
        cdef int i = 0
        while self.ptr.supported_samplerates[i]:
            ret.append(self.ptr.supported_samplerates[i])
            i += 1
        return ret

    @property
    def video_formats(self):
        """A list of supported :class:`.VideoFormat`, or ``None``."""
        if not self.ptr.pix_fmts:
            return

        ret = []
        cdef int i = 0
        while self.ptr.pix_fmts[i] != -1:
            ret.append(get_video_format(self.ptr.pix_fmts[i], 0, 0))
            i += 1
        return ret

    @property
    def audio_formats(self):
        """A list of supported :class:`.AudioFormat`, or ``None``."""
        if not self.ptr.sample_fmts:
            return

        ret = []
        cdef int i = 0
        while self.ptr.sample_fmts[i] != -1:
            ret.append(get_audio_format(self.ptr.sample_fmts[i]))
            i += 1
        return ret

    @property
    def properties(self):
        return self.desc.props

    @property
    def intra_only(self):
        return bool(self.desc.props & lib.AV_CODEC_PROP_INTRA_ONLY)

    @property
    def lossy(self):
        return bool(self.desc.props & lib.AV_CODEC_PROP_LOSSY)

    @property
    def lossless(self):
        return bool(self.desc.props & lib.AV_CODEC_PROP_LOSSLESS)

    @property
    def reorder(self):
        return bool(self.desc.props & lib.AV_CODEC_PROP_REORDER)

    @property
    def bitmap_sub(self):
        return bool(self.desc.props & lib.AV_CODEC_PROP_BITMAP_SUB)

    @property
    def text_sub(self):
        return bool(self.desc.props & lib.AV_CODEC_PROP_TEXT_SUB)

    @Capabilities.property
    def capabilities(self):
        """Flag property of :class:`.Capabilities`"""
        return self.ptr.capabilities

    draw_horiz_band = capabilities.flag_property("DRAW_HORIZ_BAND")
    dr1 = capabilities.flag_property("DR1")
    hwaccel = capabilities.flag_property("HWACCEL")
    delay = capabilities.flag_property("DELAY")
    small_last_frame = capabilities.flag_property("SMALL_LAST_FRAME")
    hwaccel_vdpau = capabilities.flag_property("HWACCEL_VDPAU")
    subframes = capabilities.flag_property("SUBFRAMES")
    experimental = capabilities.flag_property("EXPERIMENTAL")
    channel_conf = capabilities.flag_property("CHANNEL_CONF")
    neg_linesizes = capabilities.flag_property("NEG_LINESIZES")
    frame_threads = capabilities.flag_property("FRAME_THREADS")
    slice_threads = capabilities.flag_property("SLICE_THREADS")
    param_change = capabilities.flag_property("PARAM_CHANGE")
    auto_threads = capabilities.flag_property("AUTO_THREADS")
    variable_frame_size = capabilities.flag_property("VARIABLE_FRAME_SIZE")
    avoid_probing = capabilities.flag_property("AVOID_PROBING")
    hardware = capabilities.flag_property("HARDWARE")
    hybrid = capabilities.flag_property("HYBRID")
    encoder_reordered_opaque = capabilities.flag_property("ENCODER_REORDERED_OPAQUE")
    encoder_flush = capabilities.flag_property("ENCODER_FLUSH")


cdef get_codec_names():
    names = set()
    cdef const lib.AVCodec *ptr
    cdef void *opaque = NULL
    while True:
        ptr = lib.av_codec_iterate(&opaque)
        if ptr:
            names.add(ptr.name)
        else:
            break
    return names


codecs_available = get_codec_names()
codec_descriptor = wrap_avclass(lib.avcodec_get_class())


def dump_codecs():
    """Print information about available codecs."""

    print(
        """Codecs:
 D..... = Decoding supported
 .E.... = Encoding supported
 ..V... = Video codec
 ..A... = Audio codec
 ..S... = Subtitle codec
 ...I.. = Intra frame-only codec
 ....L. = Lossy compression
 .....S = Lossless compression
 ------"""
    )

    for name in sorted(codecs_available):
        try:
            e_codec = Codec(name, "w")
        except ValueError:
            e_codec = None

        try:
            d_codec = Codec(name, "r")
        except ValueError:
            d_codec = None

        # TODO: Assert these always have the same properties.
        codec = e_codec or d_codec

        try:
            print(
                " %s%s%s%s%s%s %-18s %s"
                % (
                    ".D"[bool(d_codec)],
                    ".E"[bool(e_codec)],
                    codec.type[0].upper(),
                    ".I"[codec.intra_only],
                    ".L"[codec.lossy],
                    ".S"[codec.lossless],
                    codec.name,
                    codec.long_name,
                )
            )
        except Exception as e:
            print(f"...... {codec.name:<18} ERROR: {e}")
