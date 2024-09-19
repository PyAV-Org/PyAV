from libc.stdint cimport uint8_t

cdef extern from "libavutil/buffer.h" nogil:

    AVBufferRef *av_buffer_create(uint8_t *data, size_t size, void (*free)(void *opaque, uint8_t *data), void *opaque, int flags)
    void av_buffer_unref(AVBufferRef **buf)

    cdef struct AVBufferRef:
        uint8_t *data
