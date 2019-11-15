from av.audio.format cimport get_audio_format
from av.descriptor cimport wrap_avclass
from av.enum cimport define_enum
from av.utils cimport avrational_to_fraction, flag_in_bitfield
from av.video.format cimport get_video_format

cdef extern from "codec-shims.c" nogil:
    cdef const lib.AVCodec* pyav_codec_iterate(void **opaque)


cdef object _cinit_sentinel = object()


cdef Codec wrap_codec(const lib.AVCodec *ptr):
    cdef Codec codec = Codec(_cinit_sentinel)
    codec.ptr = ptr
    codec.is_encoder = lib.av_codec_is_encoder(ptr)
    codec._init()
    return codec


CodecProperties = define_enum('CodecProperties', (
    ('NONE', 0),
    ('INTRA_ONLY', lib.AV_CODEC_PROP_INTRA_ONLY),
    ('LOSSY', lib.AV_CODEC_PROP_LOSSY),
    ('LOSSLESS', lib.AV_CODEC_PROP_LOSSLESS),
    ('REORDER', lib.AV_CODEC_PROP_REORDER),
    ('BITMAP_SUB', lib.AV_CODEC_PROP_BITMAP_SUB),
    ('TEXT_SUB', lib.AV_CODEC_PROP_TEXT_SUB),
), is_flags=True)

CodecCapabilities = define_enum('CodecCapabilities', (
    ('NONE', 0),
    ('DRAW_HORIZ_BAND', lib.CODEC_CAP_DRAW_HORIZ_BAND),
    ('DR1', lib.CODEC_CAP_DR1),
    ('TRUNCATED', lib.CODEC_CAP_TRUNCATED),
    ('HWACCEL', lib.CODEC_CAP_HWACCEL),
    ('DELAY', lib.CODEC_CAP_DELAY),
    ('SMALL_LAST_FRAME', lib.CODEC_CAP_SMALL_LAST_FRAME),
    ('HWACCEL_VDPAU', lib.CODEC_CAP_HWACCEL_VDPAU),
    ('SUBFRAMES', lib.CODEC_CAP_SUBFRAMES),
    ('EXPERIMENTAL', lib.CODEC_CAP_EXPERIMENTAL),
    ('CHANNEL_CONF', lib.CODEC_CAP_CHANNEL_CONF),
    ('NEG_LINESIZES', lib.CODEC_CAP_NEG_LINESIZES),
    ('FRAME_THREADS', lib.CODEC_CAP_FRAME_THREADS),
    ('SLICE_THREADS', lib.CODEC_CAP_SLICE_THREADS),
    ('PARAM_CHANGE', lib.CODEC_CAP_PARAM_CHANGE),
    ('AUTO_THREADS', lib.CODEC_CAP_AUTO_THREADS),
    ('VARIABLE_FRAME_SIZE', lib.CODEC_CAP_VARIABLE_FRAME_SIZE),
    ('INTRA_ONLY', lib.CODEC_CAP_INTRA_ONLY),
    ('LOSSLESS', lib.CODEC_CAP_LOSSLESS),
), is_flags=True)


class UnknownCodecError(ValueError):
    pass


cdef class Codec(object):

    """A single encoding or decoding codec.

    This object exposes information about an availible codec, and an avenue to
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

    def __cinit__(self, name, mode='r'):

        if name is _cinit_sentinel:
            return

        if mode == 'w':
            self.ptr = lib.avcodec_find_encoder_by_name(name)
            if not self.ptr:
                self.desc = lib.avcodec_descriptor_get_by_name(name)
                if self.desc:
                    self.ptr = lib.avcodec_find_encoder(self.desc.id)

        elif mode == 'r':
            self.ptr = lib.avcodec_find_decoder_by_name(name)
            if not self.ptr:
                self.desc = lib.avcodec_descriptor_get_by_name(name)
                if self.desc:
                    self.ptr = lib.avcodec_find_decoder(self.desc.id)

        else:
            raise ValueError('Invalid mode; must be "r" or "w".', mode)

        self._init(name)

        # Sanity check.
        if (mode == 'w') != self.is_encoder:
            raise RuntimeError("Found codec does not match mode.", name, mode)

    cdef _init(self, name=None):

        if not self.ptr:
            raise UnknownCodecError(name)

        if not self.desc:
            self.desc = lib.avcodec_descriptor_get(self.ptr.id)
            if not self.desc:
                raise RuntimeError('No codec descriptor for %r.' % name)

        self.is_encoder = lib.av_codec_is_encoder(self.ptr)

        # Sanity check.
        if self.is_encoder and lib.av_codec_is_decoder(self.ptr):
            raise RuntimeError('%s is both encoder and decoder.')

    def create(self):
        from .context import CodecContext
        return CodecContext.create(self)

    property is_decoder:
        def __get__(self):
            return not self.is_encoder

    property descriptor:
        def __get__(self): return wrap_avclass(self.ptr.priv_class)

    property name:
        def __get__(self): return self.ptr.name or ''
    property long_name:
        def __get__(self): return self.ptr.long_name or ''

    @property
    def type(self):
        """
        The media type of this codec.

        Examples: `'audio'`, `'video'`, `'subtitle'`.

        :type: str
        """
        return lib.av_get_media_type_string(self.ptr.type)

    property id:
        def __get__(self): return self.ptr.id

    @property
    def frame_rates(self):
        """
        A list of supported frame rates, or None.

        :type: list of fractions.Fraction
        """
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
        """
        A list of supported audio sample rates, or None.

        :type: list of int
        """
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
        """
        A list of supported video formats, or None.

        :type: list of VideoFormat
        """
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
        """
        A list of supported audio formats, or None.

        :type: list of AudioFormat
        """
        if not self.ptr.sample_fmts:
            return

        ret = []
        cdef int i = 0
        while self.ptr.sample_fmts[i] != -1:
            ret.append(get_audio_format(self.ptr.sample_fmts[i]))
            i += 1
        return ret

    # NOTE: there are some overlaps, which we define below these blocks with
    # runtime checks to make sure they are sane.

    @CodecProperties.property
    def properties(self):
        return self.desc.props

    # intra_only = properties.flag_property('INTRA_ONLY')
    # lossy = properties.flag_property('LOSSY')
    # lossless = properties.flag_property('LOSSLESS')
    reorder = properties.flag_property('REORDER')
    bitmap_sub = properties.flag_property('BITMAP_SUB')
    text_sub = properties.flag_property('TEXT_SUB')

    @CodecCapabilities.property
    def capabilities(self):
        return self.ptr.capabilities

    draw_horiz_band = capabilities.flag_property('DRAW_HORIZ_BAND')
    dr1 = capabilities.flag_property('DR1')
    truncated = capabilities.flag_property('TRUNCATED')
    hwaccel = capabilities.flag_property('HWACCEL')
    delay = capabilities.flag_property('DELAY')
    small_last_frame = capabilities.flag_property('SMALL_LAST_FRAME')
    hwaccel_vdpau = capabilities.flag_property('HWACCEL_VDPAU')
    subframes = capabilities.flag_property('SUBFRAMES')
    experimental = capabilities.flag_property('EXPERIMENTAL')
    channel_conf = capabilities.flag_property('CHANNEL_CONF')
    neg_linesizes = capabilities.flag_property('NEG_LINESIZES')
    frame_threads = capabilities.flag_property('FRAME_THREADS')
    slice_threads = capabilities.flag_property('SLICE_THREADS')
    param_change = capabilities.flag_property('PARAM_CHANGE')
    auto_threads = capabilities.flag_property('AUTO_THREADS')
    variable_frame_size = capabilities.flag_property('VARIABLE_FRAME_SIZE')
    # intra_only = capabilities.flag_property('INTRA_ONLY')
    # lossless = capabilities.flag_property('LOSSLESS')

    @property
    def intra_only(self):
        # Assert they agree.
        cdef bint c = bool(self.capabilities & 'INTRA_ONLY')
        cdef bint p = bool(self.properties & 'INTRA_ONLY')
        if (c and p) or not (c or p):
            return c
        raise RuntimeError('capabilities and properties dont agree on INTRA_ONLY')

    @property
    def lossless(self):
        # Assert they agree.
        cdef bint c = bool(self.capabilities & 'LOSSLESS')
        cdef bint p1 = bool(self.properties & 'LOSSLESS')
        cdef bint p2 = bool(self.properties & 'LOSSY')
        if (c and p1 and p2) or not (c or p1 or p2):
            return c
        raise RuntimeError('capabilities and properties dont agree on LOSSLESS and LOSSY')

    @property
    def lossy(self):
        return not self.lossless


cdef get_codec_names():
    names = set()
    cdef const lib.AVCodec *ptr
    cdef void *opaque = NULL
    while True:
        ptr = pyav_codec_iterate(&opaque)
        if ptr:
            names.add(ptr.name)
        else:
            break
    return names

codecs_available = get_codec_names()


codec_descriptor = wrap_avclass(lib.avcodec_get_class())


def dump_codecs():
    """Print information about availible codecs."""

    print '''Codecs:
 D..... = Decoding supported
 .E.... = Encoding supported
 ..V... = Video codec
 ..A... = Audio codec
 ..S... = Subtitle codec
 ...I.. = Intra frame-only codec
 ....L. = Lossy compression
 .....S = Lossless compression
 ------'''

    for name in sorted(codecs_available):

        try:
            e_codec = Codec(name, 'w')
        except ValueError:
            e_codec = None

        try:
            d_codec = Codec(name, 'r')
        except ValueError:
            d_codec = None

        # TODO: Assert these always have the same properties.
        codec = e_codec or d_codec

        print ' %s%s%s%s%s%s %-18s %s' % (
            '.D'[bool(d_codec)],
            '.E'[bool(e_codec)],
            codec.type[0].upper(),
            '.I'[codec.intra_only],
            'L.'[codec.lossless],
            '.S'[codec.lossless],
            codec.name,
            codec.long_name
        )
