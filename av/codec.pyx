from libc.stdint cimport uint64_t,int64_t
from av.utils cimport media_type_to_string, avrational_to_faction, err_check
from av.video.format cimport get_video_format
from av.audio.format cimport get_audio_format
from av.descriptor cimport wrap_avclass
from av.dictionary cimport _Dictionary

from av.dictionary import Dictionary
from fractions import Fraction

cdef object _cinit_sentinel = object()


cdef flag_in_bitfield(uint64_t bitfield, uint64_t flag):
    # Not every flag exists in every version of FFMpeg and LibAV, so we
    # define them to 0.
    if not flag:
        return None
    return bool(bitfield & flag)


cdef class Codec(object):
    
    def __cinit__(self, name, mode='r'):

        if name is _cinit_sentinel:
            return

        if mode == 'w':
            self.ptr = lib.avcodec_find_encoder_by_name(name)
            self.is_encoder = True
        elif mode == 'r':
            self.ptr = lib.avcodec_find_decoder_by_name(name)
            self.is_encoder = False
        else:
            raise ValueError('invalid mode; must be "r" or "w"', mode)

        if not self.ptr:
            raise ValueError('no codec %r' % name)

        self.desc = lib.avcodec_descriptor_get(self.ptr.id)
        if not self.desc:
            raise RuntimeError('no descriptor for %r' % name) 

    property is_decoder:
        def __get__(self): return not self.is_encoder

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
            cdef char* name
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


cdef class CodecContext(object):

    def __cinit__(self):
        self.ptr = NULL
        self._container = None
        self.options = {}

    def __init__(self):
        raise TypeError("%s cannot be instantiated from Python" %  self.__class__.__name__)

    def __dealloc__(self):
        if self.ptr and lib.avcodec_is_open(self.ptr):
            lib.avcodec_close(self.ptr)

        if self.ptr and not self._container:
            lib.avcodec_free_context(&self.ptr)

    def open(self):
        if lib.avcodec_is_open(self.ptr):
            return

        cdef _Dictionary _options = Dictionary(self.options or {})
        err_check(lib.avcodec_open2(self.ptr, self.ptr.codec, &_options.ptr))
        # avcodec_open2 will consume the options is uses
        return dict(_options)

    property codec:
        def __get__(self):
            if not self.ptr or not self.ptr.codec:
                return None
            cdef Codec codec = Codec(_cinit_sentinel)
            codec.ptr = self.ptr.codec
            return codec

    property type:
        def __get__(self): return media_type_to_string(self.ptr.codec_type)

    property profile:
        def __get__(self):
            if self.ptr.codec and lib.av_get_profile_name(self.ptr.codec, self.ptr.profile):
                return lib.av_get_profile_name(self.ptr.codec, self.ptr.profile)
            else:
                return None

    property bit_rate:
        def __get__(self):
            return self.ptr.bit_rate
        def __set__(self, int64_t value):
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

    # should replace with format
    property pix_fmt:
        def __get__(self):
            cdef char* name = lib.av_get_pix_fmt_name(self.ptr.pix_fmt)
            return <str>name if name else None

        def __set__(self, value):
            cdef lib.AVPixelFormat pix_fmt = lib.av_get_pix_fmt(value)
            if pix_fmt < 0:
                raise ValueError('not a pixel format: %r' % value)
            self.ptr.pix_fmt = pix_fmt

    property time_base:
        def __get__(self):
            return avrational_to_faction(&self.ptr.time_base)

        def __set__(self, value):
            rate = Fraction(value or 24)
            self.ptr.time_base.num = rate.denominator
            self.ptr.time_base.den = rate.numerator

    property width:
        def __get__(self):
            return self.ptr.width
        def __set__(self, value):
            self.ptr.width = value

    property height:
        def __get__(self):
            return self.ptr.height
        def __set__(self, value):
            self.ptr.height = value

    property sample_rate:
        """samples per second """
        def __get__(self): return self.ptr.sample_rate
        def __set__(self, int value): self.ptr.sample_rate = value

    property sample_fmt:
        def __get__(self):
            cdef char* name = lib.av_get_sample_fmt_name(self.ptr.sample_fmt)
            return <str>name if name else None

        def __set__(self, value):
            cdef lib.AVSampleFormat sample_fmt = lib.av_get_sample_fmt(value)
            if sample_fmt < 0:
                raise ValueError('not a sample format: %r' % value)
            self.ptr.sample_fmt = sample_fmt

    property frame_size:
        def __get__(self):
            return self.ptr.frame_size
        def __set__(self, value):
            self.ptr.frame_size = value

    property channels:
        def __get__(self):
            return self.ptr.channels
        def __set__(self, value):
            self.ptr.channels = value
            self.ptr.channel_layout = lib.av_get_default_channel_layout(value)

    property channel_layout:
        def __get__(self):
            return self.ptr.channel_layout

codecs_availible = set()
cdef lib.AVCodec *ptr = lib.av_codec_next(NULL)
while ptr:
    codecs_availible.add(ptr.name)
    ptr = lib.av_codec_next(ptr)


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

    for name in sorted(codecs_availible):
        try:
            e_codec = Codec(name, 'w')
        except ValueError:
            e_codec = None
        try:
            d_codec = Codec(name, 'r')
        except ValueError:
            d_codec = None
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

