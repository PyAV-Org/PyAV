cdef extern from "libavfilter/avcodec.h" nogil:


    cdef AVFilterBufferRef* avfilter_get_video_buffer_ref_from_frame(
        const AVFrame *frame,
        int perms
    )

    cdef AVFilterBufferRef* avfilter_get_audio_buffer_ref_from_frame(
        const AVFrame *frame,
        int perms
    )

    cdef int avfilter_fill_frame_from_audio_buffer_ref(
        AVFrame *frame,
        const AVFilterBufferRef *samplesref
    )

    cdef int avfilter_fill_frame_from_video_buffer_ref(
        AVFrame *frame,
        const AVFilterBufferRef *picref
    )

