from av.audio.stream cimport AudioStream


cdef extern from "libavcodec/avcodec.h":
    ctypedef struct AVCodecContext:
        pass

cdef extern from "libavformat/avformat.h":
    ctypedef struct AVFormatContext:
        pass

cdef extern from "loudnorm_impl.h":
    char* loudnorm_get_stats(
        AVFormatContext* fmt_ctx,
        int audio_stream_index,
        const char* loudnorm_args
    ) nogil

cpdef bytes stats(str loudnorm_args, AudioStream stream)
