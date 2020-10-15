from libc.stdint cimport int64_t, uint8_t


cdef int pyio_read(void *opaque, uint8_t *buf, int buf_size) nogil

cdef int pyio_write(void *opaque, uint8_t *buf, int buf_size) nogil

cdef int64_t pyio_seek(void *opaque, int64_t offset, int whence) nogil
