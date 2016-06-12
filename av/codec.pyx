from libc.stdint cimport uint64_t

from av.utils cimport media_type_to_string
from av.video.format cimport get_video_format
from av.descriptor cimport wrap_avclass

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
        def __get__(self): return <int>self.ptr.sample_fmts

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

    def __cinit__(self, x):
        if x is not _cinit_sentinel:
            raise RuntimeError('cannot instantiate CodecContext')


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

