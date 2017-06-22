cdef extern from "libavfilter/buffersrc.h" nogil:

    int av_buffersrc_write_frame(
        AVFilterContext *ctx,
        const AVFrame *frame
    )
