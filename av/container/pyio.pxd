from libc.stdint cimport uint8_t, int64_t


cdef int pyio_read(void *opaque, uint8_t *buf, int buf_size) nogil

cdef int pyio_write(void *opaque, uint8_t *buf, int buf_size) nogil

cdef int64_t pyio_seek(void *opaque, int64_t offset, int whence) nogil
