cdef extern from "libavutil/samplefmt.h" nogil:

    cdef enum AVSampleFormat:
        AV_SAMPLE_FMT_NONE
        AV_SAMPLE_FMT_U8
        AV_SAMPLE_FMT_S16
        AV_SAMPLE_FMT_S32
        AV_SAMPLE_FMT_FLT
        AV_SAMPLE_FMT_DBL
        AV_SAMPLE_FMT_U8P
        AV_SAMPLE_FMT_S16P
        AV_SAMPLE_FMT_S32P
        AV_SAMPLE_FMT_FLTP
        AV_SAMPLE_FMT_DBLP
        AV_SAMPLE_FMT_NB  # Number.

    # Find by name.
    cdef AVSampleFormat av_get_sample_fmt(char* name)

    # Inspection.
    cdef char * av_get_sample_fmt_name(AVSampleFormat sample_fmt)
    cdef int    av_get_bytes_per_sample(AVSampleFormat sample_fmt)
    cdef int    av_sample_fmt_is_planar(AVSampleFormat sample_fmt)

    # Alternative forms.
    cdef AVSampleFormat av_get_packed_sample_fmt(AVSampleFormat sample_fmt)
    cdef AVSampleFormat av_get_planar_sample_fmt(AVSampleFormat sample_fmt)

    cdef int av_samples_alloc(
        uint8_t** audio_data,
        int* linesize,
        int nb_channels,
        int nb_samples,
        AVSampleFormat sample_fmt,
        int align
    )

    cdef int av_samples_get_buffer_size(
        int *linesize,
        int nb_channels,
        int nb_samples,
        AVSampleFormat sample_fmt,
        int align
    )

    cdef int av_samples_fill_arrays(
        uint8_t **audio_data,
        int *linesize,
        const uint8_t *buf,
        int nb_channels,
        int nb_samples,
        AVSampleFormat sample_fmt,
        int align
    )

    cdef int av_samples_set_silence(
        uint8_t **audio_data,
        int offset,
        int nb_samples,
        int nb_channels,
        AVSampleFormat sample_fmt
    )
