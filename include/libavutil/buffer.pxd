from libc.stdint cimport intptr_t, uint8_t

cdef extern from "libavutil/buffer.h" nogil:
    AVBufferRef *av_buffer_create(uint8_t *data, size_t size, void (*free)(void *opaque, uint8_t *data), void *opaque, int flags)
    AVBufferRef* av_buffer_ref(AVBufferRef *buf)
    void av_buffer_unref(AVBufferRef **buf)

    cdef struct AVBuffer:
        uint8_t *data
        int size
        intptr_t refcount
        void (*free)(void *opaque, uint8_t *data)
        void *opaque
        int flags
    cdef struct AVBufferRef:
        AVBuffer *buffer
        uint8_t *data
        int size
