cimport libav as lib

from av.audio.format cimport get_audio_format
from av.codec.hwaccel cimport wrap_hwconfig
from av.descriptor cimport wrap_avclass
from av.utils cimport avrational_to_fraction
from av.video.format cimport get_video_format

from enum import Flag, IntEnum


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


class Capabilities(IntEnum):
    none = 0
    draw_horiz_band = lib.AV_CODEC_CAP_DRAW_HORIZ_BAND
    dr1 = lib.AV_CODEC_CAP_DR1
    hwaccel = 1 << 4
    delay = lib.AV_CODEC_CAP_DELAY
    small_last_frame = lib.AV_CODEC_CAP_SMALL_LAST_FRAME
    hwaccel_vdpau = 1 << 7
    experimental = lib.AV_CODEC_CAP_EXPERIMENTAL
    channel_conf = lib.AV_CODEC_CAP_CHANNEL_CONF
    neg_linesizes = 1 << 11
    frame_threads = lib.AV_CODEC_CAP_FRAME_THREADS
    slice_threads = lib.AV_CODEC_CAP_SLICE_THREADS
    param_change = lib.AV_CODEC_CAP_PARAM_CHANGE
    auto_threads = lib.AV_CODEC_CAP_OTHER_THREADS
    variable_frame_size = lib.AV_CODEC_CAP_VARIABLE_FRAME_SIZE
    avoid_probing = lib.AV_CODEC_CAP_AVOID_PROBING
    hardware = lib.AV_CODEC_CAP_HARDWARE
    hybrid = lib.AV_CODEC_CAP_HYBRID
    encoder_reordered_opaque = 1 << 20
    encoder_flush = 1 << 21
    encoder_recon_frame = 1 << 22


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

    def __repr__(self):
        mode = self.mode
        return f"<av.{self.__class__.__name__} {self.name} {mode=}>"

    def create(self, kind = None):
        """Create a :class:`.CodecContext` for this codec.

        :param str kind: Gives a hint to static type checkers for what exact CodecContext is used.
        """
        from .context import CodecContext
        return CodecContext.create(self)

    @property
    def mode(self):
        return "w" if self.is_encoder else "r"

    @property
    def is_decoder(self):
        return not self.is_encoder

    @property
    def descriptor(self): return wrap_avclass(self.ptr.priv_class)

    @property
    def name(self): return self.ptr.name or ""

    @property
    def canonical_name(self):
        """
        Returns the name of the codec, not a specific encoder.
        """
        return lib.avcodec_get_name(self.ptr.id)

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
    def hardware_configs(self):
        if self._hardware_configs:
            return self._hardware_configs
        ret = []
        cdef int i = 0
        cdef const lib.AVCodecHWConfig *ptr
        while True:
            ptr = lib.avcodec_get_hw_config(self.ptr, i)
            if not ptr:
                break
            ret.append(wrap_hwconfig(ptr))
            i += 1
        ret = tuple(ret)
        self._hardware_configs = ret
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

    @property
    def capabilities(self):
        """
        Get the capabilities bitmask of the codec.

        This method returns an integer representing the codec capabilities bitmask,
        which can be used to check specific codec features by performing bitwise
        operations with the Capabilities enum values.

        :example:

        .. code-block:: python

            from av.codec import Codec, Capabilities

            codec = Codec("h264", "w")

            # Check if the codec can be fed a final frame with a smaller size.
            # This can be used to prevent truncation of the last audio samples.
            small_last_frame = bool(codec.capabilities & Capabilities.small_last_frame)

        :rtype: int
        """
        return self.ptr.capabilities

    @property
    def experimental(self):
        """
        Check if codec is experimental and is thus avoided in favor of non experimental encoders.

        :rtype: bool
        """
        return bool(self.ptr.capabilities & lib.AV_CODEC_CAP_EXPERIMENTAL)

    @property
    def delay(self):
        """
        If true, encoder or decoder requires flushing with `None` at the end in order to give the complete and correct output.

        :rtype: bool
        """
        return bool(self.ptr.capabilities & lib.AV_CODEC_CAP_DELAY)

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

def dump_hwconfigs():
    print("Hardware configs:")
    for name in sorted(codecs_available):
        try:
            codec = Codec(name, "r")
        except ValueError:
            continue

        configs = codec.hardware_configs
        if not configs:
            continue

        print("   ", codec.name)
        for config in configs:
            print("       ", config)
