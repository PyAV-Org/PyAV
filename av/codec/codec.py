from enum import Flag, IntEnum

import cython
from cython.cimports import libav as lib
from cython.cimports.av.audio.format import get_audio_format
from cython.cimports.av.codec.hwaccel import wrap_hwconfig
from cython.cimports.av.descriptor import wrap_avclass
from cython.cimports.av.utils import avrational_to_fraction
from cython.cimports.av.video.format import VideoFormat, get_pix_fmt, get_video_format
from cython.cimports.libc.stdlib import free, malloc

_cinit_sentinel = cython.declare(object, object())


@cython.cfunc
def wrap_codec(ptr: cython.pointer[cython.const[lib.AVCodec]]) -> Codec:
    codec: Codec = Codec(_cinit_sentinel)
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


@cython.cclass
class Codec:
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

    @cython.cfunc
    def _init(self, name=None):
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

    def create(self, kind=None):
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
    def descriptor(self):
        return wrap_avclass(self.ptr.priv_class)

    @property
    def name(self):
        return self.ptr.name or ""

    @property
    def canonical_name(self):
        """
        Returns the name of the codec, not a specific encoder.
        """
        return lib.avcodec_get_name(self.ptr.id)

    @property
    def long_name(self):
        return self.ptr.long_name or ""

    @property
    def type(self):
        """
        The media type of this codec.

        E.g: ``'audio'``, ``'video'``, ``'subtitle'``.

        """
        return lib.av_get_media_type_string(self.ptr.type)

    @property
    def id(self):
        return self.ptr.id

    @property
    def frame_rates(self):
        """A list of supported frame rates (:class:`fractions.Fraction`), or ``None``."""
        if not self.ptr.supported_framerates:
            return

        ret: list = []
        i: cython.int = 0
        while self.ptr.supported_framerates[i].denum:
            ret.append(
                avrational_to_fraction(cython.address(self.ptr.supported_framerates[i]))
            )
            i += 1
        return ret

    @property
    def audio_rates(self):
        """A list of supported audio sample rates (``int``), or ``None``."""
        if not self.ptr.supported_samplerates:
            return

        ret: list = []
        i: cython.int = 0
        while self.ptr.supported_samplerates[i]:
            ret.append(self.ptr.supported_samplerates[i])
            i += 1
        return ret

    @property
    def video_formats(self):
        """A list of supported :class:`.VideoFormat`, or ``None``."""
        if not self.ptr.pix_fmts:
            return

        ret: list = []
        i: cython.int = 0
        while self.ptr.pix_fmts[i] != -1:
            ret.append(get_video_format(self.ptr.pix_fmts[i], 0, 0))
            i += 1
        return ret

    @property
    def audio_formats(self):
        """A list of supported :class:`.AudioFormat`, or ``None``."""
        if not self.ptr.sample_fmts:
            return

        ret: list = []
        i: cython.int = 0
        while self.ptr.sample_fmts[i] != -1:
            ret.append(get_audio_format(self.ptr.sample_fmts[i]))
            i += 1
        return ret

    @property
    def hardware_configs(self):
        if self._hardware_configs:
            return self._hardware_configs
        ret: list = []
        i: cython.int = 0
        ptr: cython.pointer[cython.const[lib.AVCodecHWConfig]]
        while True:
            ptr = lib.avcodec_get_hw_config(self.ptr, i)
            if not ptr:
                break
            ret.append(wrap_hwconfig(ptr))
            i += 1
        self._hardware_configs = tuple(ret)
        return self._hardware_configs

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


@cython.cfunc
def get_codec_names():
    names: cython.set = set()
    ptr = cython.declare(cython.pointer[cython.const[lib.AVCodec]])
    opaque: cython.p_void = cython.NULL
    while True:
        ptr = lib.av_codec_iterate(cython.address(opaque))
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


def find_best_pix_fmt_of_list(pix_fmts, src_pix_fmt, has_alpha=False):
    """
    Find the best pixel format to convert to given a source format.

    Wraps :ffmpeg:`avcodec_find_best_pix_fmt_of_list`.

    :param pix_fmts: Iterable of pixel formats to choose from (str or VideoFormat).
    :param src_pix_fmt: Source pixel format (str or VideoFormat).
    :param bool has_alpha: Whether the source alpha channel is used.
    :return: (best_format, loss)
    :rtype: (VideoFormat | None, int)
    """
    src: lib.AVPixelFormat
    best: lib.AVPixelFormat
    c_list: cython.pointer[lib.AVPixelFormat] = cython.NULL
    n: cython.Py_ssize_t
    i: cython.Py_ssize_t
    item: object
    c_loss: cython.int

    if pix_fmts is None:
        raise TypeError("pix_fmts must not be None")

    pix_fmts = tuple(pix_fmts)
    if not pix_fmts:
        return None, 0

    if isinstance(src_pix_fmt, VideoFormat):
        src = cython.cast(VideoFormat, src_pix_fmt).pix_fmt
    else:
        src = get_pix_fmt(cython.cast(str, src_pix_fmt))

    n = len(pix_fmts)
    c_list = cython.cast(
        cython.pointer[lib.AVPixelFormat],
        malloc((n + 1) * cython.sizeof(lib.AVPixelFormat)),
    )
    if c_list == cython.NULL:
        raise MemoryError()

    try:
        for i in range(n):
            item = pix_fmts[i]
            if isinstance(item, VideoFormat):
                c_list[i] = cython.cast(VideoFormat, item).pix_fmt
            else:
                c_list[i] = get_pix_fmt(cython.cast(str, item))
        c_list[n] = lib.AV_PIX_FMT_NONE

        c_loss = 0
        best = lib.avcodec_find_best_pix_fmt_of_list(
            c_list, src, 1 if has_alpha else 0, cython.address(c_loss)
        )
        return get_video_format(best, 0, 0), c_loss
    finally:
        if c_list != cython.NULL:
            free(c_list)
