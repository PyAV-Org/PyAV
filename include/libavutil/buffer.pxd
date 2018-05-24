cdef extern from "libavutil/buffer.h" nogil:
    cdef struct AVBuffer
    cdef struct AVBufferRef

    cdef AVBufferRef* av_buffer_ref(AVBufferRef *buf)
    cdef void av_buffer_unref(AVBufferRef **buf)

