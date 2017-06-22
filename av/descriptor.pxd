cimport libav as lib


cdef class Descriptor(object):

    # These are present as:
    # - AVCodecContext.av_class
    # - AVFormatContext.av_class
    # - AVCodec.priv_class
    # - AVOutputFormat.priv_class
    # - AVInputFormat.priv_class

    cdef lib.AVClass *ptr

    cdef object _options # Option list cache.


cdef Descriptor wrap_avclass(lib.AVClass*)
