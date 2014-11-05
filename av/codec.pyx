from av.utils cimport media_type_to_string
from av.video.format cimport get_video_format

cdef object _cinit_sentinel = object()


cdef class Codec(object):
    
    def __cinit__(self, name):
        if name is _cinit_sentinel:
            return
        self.eptr = lib.avcodec_find_encoder_by_name(name)
        self.dptr = lib.avcodec_find_decoder_by_name(name)
        if not (self.eptr or self.dptr):
            raise ValueError('no codec %r' % name)
        self.desc = lib.avcodec_descriptor_get(self.ptr().id)
        if not self.desc:
            raise RuntimeError('no descriptor for %r' % name) 


    cdef lib.AVCodec* ptr(self):
        return self.eptr or self.dptr

    cdef uint64_t capabilities(self):
        return (self.eptr.capabilities if self.eptr else 0) | (self.dptr.capabilities if self.dptr else 0)

    property name:
        def __get__(self): return self.ptr().name or ''
    property long_name:
        def __get__(self): return self.ptr().long_name or ''
    property type:
        def __get__(self): return media_type_to_string(self.ptr().type)
    property id:
        def __get__(self): return self.ptr().id

    property is_encoder:
        def __get__(self): return self.eptr != NULL
    property is_decoder:
        def __get__(self): return self.dptr != NULL

    property frame_rates:
        def __get__(self): return <int>self.ptr().supported_framerates
    property audio_rates:
        def __get__(self): return <int>self.ptr().supported_samplerates

    property video_formats:
        def __get__(self):

            if not self.ptr().pix_fmts:
                return

            ret = []
            cdef lib.AVPixelFormat *ptr = self.ptr().pix_fmts
            while ptr[0] != -1:
                ret.append(get_video_format(ptr[0], 0, 0))
                ptr += 1

            return ret

    property audio_formats:
        def __get__(self): return <int>self.ptr().sample_fmts

    # Capabilities.
    property draw_horiz_band:
        def __get__(self): return bool(self.capabilities() & lib.CODEC_CAP_DRAW_HORIZ_BAND)
    property dr1:
        def __get__(self): return bool(self.capabilities() & lib.CODEC_CAP_DR1)
    property truncated:
        def __get__(self): return bool(self.capabilities() & lib.CODEC_CAP_TRUNCATED)
    property hwaccel:
        def __get__(self): return bool(self.capabilities() & lib.CODEC_CAP_HWACCEL)
    property delay:
        def __get__(self): return bool(self.capabilities() & lib.CODEC_CAP_DELAY)
    property small_last_frame:
        def __get__(self): return bool(self.capabilities() & lib.CODEC_CAP_SMALL_LAST_FRAME)
    property hwaccel_vdpau:
        def __get__(self): return bool(self.capabilities() & lib.CODEC_CAP_HWACCEL_VDPAU)
    property subframes:
        def __get__(self): return bool(self.capabilities() & lib.CODEC_CAP_SUBFRAMES)
    property experimental:
        def __get__(self): return bool(self.capabilities() & lib.CODEC_CAP_EXPERIMENTAL)
    property channel_conf:
        def __get__(self): return bool(self.capabilities() & lib.CODEC_CAP_CHANNEL_CONF)
    property neg_linesizes:
        def __get__(self): return bool(self.capabilities() & lib.CODEC_CAP_NEG_LINESIZES)
    property frame_threads:
        def __get__(self): return bool(self.capabilities() & lib.CODEC_CAP_FRAME_THREADS)
    property slice_threads:
        def __get__(self): return bool(self.capabilities() & lib.CODEC_CAP_SLICE_THREADS)
    property param_change:
        def __get__(self): return bool(self.capabilities() & lib.CODEC_CAP_PARAM_CHANGE)
    property auto_threads:
        def __get__(self): return bool(self.capabilities() & lib.CODEC_CAP_AUTO_THREADS)
    property variable_frame_size:
        def __get__(self): return bool(self.capabilities() & lib.CODEC_CAP_VARIABLE_FRAME_SIZE)

    # Capabilities and properties overlap.
    # TODO: Is this really the right way to combine these things?
    property intra_only:
        def __get__(self): return bool(
            self.capabilities() & lib.CODEC_CAP_INTRA_ONLY or
            self.desc.props & lib.AV_CODEC_PROP_INTRA_ONLY
        )
    property lossless:
        def __get__(self): return bool(
            self.capabilities() & lib.CODEC_CAP_LOSSLESS or
            self.desc.props & lib.AV_CODEC_PROP_LOSSLESS
        )
    property lossy:
        def __get__(self): return bool(
            self.desc.props & lib.AV_CODEC_PROP_LOSSY or
            not self.lossless
        )

    # Properties.
    # property reorder:
    #    def __get__(self): return bool(self.desc.props & lib.AV_CODEC_PROP_REORDER)
    property bitmap_sub:
        def __get__(self): return bool(self.desc.props & lib.AV_CODEC_PROP_BITMAP_SUB)
    property text_sub:
        def __get__(self): return bool(self.desc.props & lib.AV_CODEC_PROP_TEXT_SUB)


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
    for name in sorted(codecs_availible):
        codec = Codec(name)
        print ' %s%s%s%s%s%s %-18s %s' % (
            '.D'[codec.is_decoder],
            '.E'[codec.is_encoder],
            codec.type[0].upper(),
            '.I'[codec.intra_only],
            'L.'[codec.lossless],
            '.S'[codec.lossless],
            codec.name,
            codec.long_name
        )

