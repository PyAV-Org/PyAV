cdef extern from "libavfilter/buffersink.h" nogil:

    cdef int av_buffersink_get_buffer_ref(
        AVFilterContext *buffer_sink,
        AVFilterBufferRef **bufref,
        int flags    
    )

    cdef void avfilter_unref_bufferp(
        AVFilterBufferRef **ref
    )
