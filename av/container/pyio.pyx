from libc.string cimport memcpy
cimport libav as lib

from av.container.core cimport Container
from av.error cimport stash_exception


cdef int pyio_read(void *opaque, uint8_t *buf, int buf_size) nogil:
    with gil:
        return pyio_read_gil(opaque, buf, buf_size)

cdef int pyio_read_gil(void *opaque, uint8_t *buf, int buf_size):
    cdef Container self
    cdef bytes res
    try:
        self = <Container>opaque
        res = self.fread(buf_size)
        memcpy(buf, <void*><char*>res, len(res))
        self.pos += len(res)
        if not res:
            return lib.AVERROR_EOF
        return len(res)
    except Exception as e:
        return stash_exception()


cdef int pyio_write(void *opaque, uint8_t *buf, int buf_size) nogil:
    with gil:
        return pyio_write_gil(opaque, buf, buf_size)

cdef int pyio_write_gil(void *opaque, uint8_t *buf, int buf_size):
    cdef Container self
    cdef bytes bytes_to_write
    cdef int bytes_written
    try:
        self = <Container>opaque
        bytes_to_write = buf[:buf_size]
        ret_value = self.fwrite(bytes_to_write)
        bytes_written = ret_value if isinstance(ret_value, int) else buf_size
        self.pos += bytes_written
        return bytes_written
    except Exception as e:
        return stash_exception()


cdef int64_t pyio_seek(void *opaque, int64_t offset, int whence) nogil:
    # Seek takes the standard flags, but also a ad-hoc one which means that
    # the library wants to know how large the file is. We are generally
    # allowed to ignore this.
    if whence == lib.AVSEEK_SIZE:
        return -1
    with gil:
        return pyio_seek_gil(opaque, offset, whence)

cdef int64_t pyio_seek_gil(void *opaque, int64_t offset, int whence):
    cdef Container self
    try:
        self = <Container>opaque
        res = self.fseek(offset, whence)

        # Track the position for the user.
        if whence == 0:
            self.pos = offset
        elif whence == 1:
            self.pos += offset
        else:
            self.pos_is_valid = False
        if res is None:
            if self.pos_is_valid:
                res = self.pos
            else:
                res = self.ftell()
        return res

    except Exception as e:
        return stash_exception()
