from av.utils cimport media_type_to_string
from av.video.format cimport get_video_format

cdef object _cinit_sentinel = object()


cdef class Codec(object):
    
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


cdef class Encoder(Codec):
    
    def __cinit__(self, name):
        self.ptr = lib.avcodec_find_encoder_by_name(name)
        if not self.ptr:
            raise ValueError('no encoder %r' % name)


cdef class Decoder(Codec):

    def __cinit__(self, name):
        self.ptr = lib.avcodec_find_decoder_by_name(name)
        if not self.ptr:
            raise ValueError('no decoder %r' % name)


cdef class CodecContext(object):

    def __cinit__(self, x):
        if x is not _cinit_sentinel:
            raise RuntimeError('cannot instantiate CodecContext')

