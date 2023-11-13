from libc.stdint cimport int64_t, uint8_t


cdef extern from "libswresample/swresample.h" nogil:

    cdef int   swresample_version()
    cdef char* swresample_configuration()
    cdef char* swresample_license()

    cdef struct SwrContext:
        pass

    cdef SwrContext* swr_alloc_set_opts(
        SwrContext *ctx,
        int64_t out_ch_layout,
        AVSampleFormat out_sample_fmt,
        int out_sample_rate,
        int64_t in_ch_layout,
        AVSampleFormat in_sample_fmt,
        int in_sample_rate,
        int log_offset,
        void *log_ctx  # logging context, can be NULL
    )

    cdef int swr_convert(
        SwrContext *ctx,
        uint8_t ** out_buffer,
        int out_count,
        uint8_t **in_buffer,
        int in_count
    )
    # Gets the delay the next input sample will
    # experience relative to the next output sample.
    cdef int64_t swr_get_delay(SwrContext *s, int64_t base)

    cdef SwrContext* swr_alloc()
    cdef int swr_init(SwrContext* ctx)
    cdef void swr_free(SwrContext **ctx)
    cdef void swr_close(SwrContext *ctx)
