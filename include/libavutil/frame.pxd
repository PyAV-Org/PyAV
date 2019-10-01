cdef extern from "libavutil/frame.h" nogil:

    cdef AVFrame* av_frame_alloc()
    cdef void av_frame_free(AVFrame**)
    cdef int av_frame_ref(AVFrame *dst, const AVFrame *src)
    cdef AVFrame* av_frame_clone(const AVFrame *src)
    cdef void av_frame_unref(AVFrame *frame)
    cdef void av_frame_move_ref(AVFrame *dst, AVFrame *src)
    cdef int av_frame_get_buffer(AVFrame *frame, int align)
    cdef int av_frame_is_writable(AVFrame *frame)
    cdef int av_frame_make_writable(AVFrame *frame)
    cdef int av_frame_copy(AVFrame *dst, const AVFrame *src)
    cdef int av_frame_copy_props(AVFrame *dst, const AVFrame *src)
    cdef AVFrameSideData* av_frame_get_side_data(AVFrame *frame, AVFrameSideDataType type)
