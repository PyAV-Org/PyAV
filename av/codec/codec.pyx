from libc.stdint cimport uint64_t

from av.audio.format cimport get_audio_format
from av.descriptor cimport wrap_avclass
from av.utils cimport flag_in_bitfield, media_type_to_string
from av.video.format cimport get_video_format

cdef object _cinit_sentinel = object()



cdef Codec wrap_codec(lib.AVCodec *ptr):
    cdef Codec codec = Codec(_cinit_sentinel)
    codec.ptr = ptr
    codec.is_encoder = lib.av_codec_is_encoder(ptr)
    codec._init()
    return codec

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
    property type:
        def __get__(self): return media_type_to_string(self.ptr.type)
    property id:
        def __get__(self): return self.ptr.id

    property frame_rates:
        def __get__(self): return <int>self.ptr.supported_framerates
    property audio_rates:
        def __get__(self): return <int>self.ptr.supported_samplerates

    property video_formats:
        def __get__(self):

            if not self.ptr.pix_fmts:
                return

            ret = []
            cdef lib.AVPixelFormat *ptr = self.ptr.pix_fmts
            while ptr[0] != -1:
                ret.append(get_video_format(ptr[0], 0, 0))
                ptr += 1
            return ret

    property audio_formats:
       def __get__(self):

           if not self.ptr.sample_fmts:
               return

           ret = []
           cdef lib.AVSampleFormat *ptr = self.ptr.sample_fmts
           while ptr[0] != -1:
               ret.append(get_audio_format(ptr[0]))
               ptr += 1
           return ret


    # Capabilities.
    property draw_horiz_band:
        def __get__(self): return flag_in_bitfield(self.ptr.capabilities, lib.CODEC_CAP_DRAW_HORIZ_BAND)
    property dr1:
        def __get__(self): return flag_in_bitfield(self.ptr.capabilities, lib.CODEC_CAP_DR1)
    property truncated:
        def __get__(self): return flag_in_bitfield(self.ptr.capabilities, lib.CODEC_CAP_TRUNCATED)
    property hwaccel:
        def __get__(self): return flag_in_bitfield(self.ptr.capabilities, lib.CODEC_CAP_HWACCEL)
    property delay:
        def __get__(self): return flag_in_bitfield(self.ptr.capabilities, lib.CODEC_CAP_DELAY)
    property small_last_frame:
        def __get__(self): return flag_in_bitfield(self.ptr.capabilities, lib.CODEC_CAP_SMALL_LAST_FRAME)
    property hwaccel_vdpau:
        def __get__(self): return flag_in_bitfield(self.ptr.capabilities, lib.CODEC_CAP_HWACCEL_VDPAU)
    property subframes:
        def __get__(self): return flag_in_bitfield(self.ptr.capabilities, lib.CODEC_CAP_SUBFRAMES)
    property experimental:
        def __get__(self): return flag_in_bitfield(self.ptr.capabilities, lib.CODEC_CAP_EXPERIMENTAL)
    property channel_conf:
        def __get__(self): return flag_in_bitfield(self.ptr.capabilities, lib.CODEC_CAP_CHANNEL_CONF)
    property neg_linesizes:
        def __get__(self): return flag_in_bitfield(self.ptr.capabilities, lib.CODEC_CAP_NEG_LINESIZES)
    property frame_threads:
        def __get__(self): return flag_in_bitfield(self.ptr.capabilities, lib.CODEC_CAP_FRAME_THREADS)
    property slice_threads:
        def __get__(self): return flag_in_bitfield(self.ptr.capabilities, lib.CODEC_CAP_SLICE_THREADS)
    property param_change:
        def __get__(self): return flag_in_bitfield(self.ptr.capabilities, lib.CODEC_CAP_PARAM_CHANGE)
    property auto_threads:
        def __get__(self): return flag_in_bitfield(self.ptr.capabilities, lib.CODEC_CAP_AUTO_THREADS)
    property variable_frame_size:
        def __get__(self): return flag_in_bitfield(self.ptr.capabilities, lib.CODEC_CAP_VARIABLE_FRAME_SIZE)

    # Capabilities and properties overlap.
    # TODO: Is this really the right way to combine these things?
    property intra_only:
        def __get__(self): return (
            flag_in_bitfield(self.ptr.capabilities, lib.CODEC_CAP_INTRA_ONLY) or
            flag_in_bitfield(self.desc.props, lib.AV_CODEC_PROP_INTRA_ONLY)
        )
    property lossless:
        def __get__(self): return (
            flag_in_bitfield(self.ptr.capabilities, lib.CODEC_CAP_LOSSLESS) or
            flag_in_bitfield(self.desc.props, lib.AV_CODEC_PROP_LOSSLESS)
        )
    property lossy:
        def __get__(self): return (
            flag_in_bitfield(self.desc.props, lib.AV_CODEC_PROP_LOSSY) or
            not self.lossless
        )

    # Properties.
    property reorder:
        def __get__(self): return flag_in_bitfield(self.desc.props, lib.AV_CODEC_PROP_REORDER)
    property bitmap_sub:
        def __get__(self): return flag_in_bitfield(self.desc.props, lib.AV_CODEC_PROP_BITMAP_SUB)
    property text_sub:
        def __get__(self): return flag_in_bitfield(self.desc.props, lib.AV_CODEC_PROP_TEXT_SUB)


codecs_available = set()
cdef lib.AVCodec *ptr = lib.av_codec_next(NULL)
while ptr:
    codecs_available.add(ptr.name)
    ptr = lib.av_codec_next(ptr)


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
