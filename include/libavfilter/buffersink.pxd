cdef extern from "libavfilter/buffersink.h" nogil:

    int av_buffersink_get_frame(
        AVFilterContext *ctx,
        AVFrame *frame
    )
