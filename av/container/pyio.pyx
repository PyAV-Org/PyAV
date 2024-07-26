cimport libav as lib
from libc.string cimport memcpy

from av.error cimport stash_exception

ctypedef int64_t (*seek_func_t)(void *opaque, int64_t offset, int whence) noexcept nogil


cdef class PyIOFile:
    def __cinit__(self, file, buffer_size, writeable=None):
        self.file = file

        cdef seek_func_t seek_func = NULL

        readable = getattr(self.file, "readable", None)
        writable = getattr(self.file, "writable", None)
        seekable = getattr(self.file, "seekable", None)
        self.fread = getattr(self.file, "read", None)
        self.fwrite = getattr(self.file, "write", None)
        self.fseek = getattr(self.file, "seek", None)
        self.ftell = getattr(self.file, "tell", None)
        self.fclose = getattr(self.file, "close", None)

        # To be seekable the file object must have `seek` and `tell` methods.
        # If it also has a `seekable` method, it must return True.
        if (
            self.fseek is not None
            and self.ftell is not None
            and (seekable is None or seekable())
        ):
            seek_func = pyio_seek

        if writeable is None:
            writeable = self.fwrite is not None

        if writeable:
            if self.fwrite is None or (writable is not None and not writable()):
                raise ValueError("File object has no write() method, or writable() returned False.")
        else:
            if self.fread is None or (readable is not None and not readable()):
                raise ValueError("File object has no read() method, or readable() returned False.")

        self.pos = 0
        self.pos_is_valid = True

        # This is effectively the maximum size of reads.
        self.buffer = <unsigned char*>lib.av_malloc(buffer_size)

        self.iocontext = lib.avio_alloc_context(
            self.buffer,
            buffer_size,
            writeable,
            <void*>self,  # User data.
            pyio_read,
            pyio_write,
            seek_func
        )

        if seek_func:
            self.iocontext.seekable = lib.AVIO_SEEKABLE_NORMAL
        self.iocontext.max_packet_size = buffer_size

    def __dealloc__(self):
        with nogil:
            # FFmpeg will not release custom input, so it's up to us to free it.
            # Do not touch our original buffer as it may have been freed and replaced.
            if self.iocontext:
                lib.av_freep(&self.iocontext.buffer)
                lib.av_freep(&self.iocontext)

            # We likely errored badly if we got here, and so are still
            # responsible for our buffer.
            else:
                lib.av_freep(&self.buffer)


cdef int pyio_read(void *opaque, uint8_t *buf, int buf_size) noexcept nogil:
    with gil:
        return pyio_read_gil(opaque, buf, buf_size)

cdef int pyio_read_gil(void *opaque, uint8_t *buf, int buf_size) noexcept:
    cdef PyIOFile self
    cdef bytes res
    try:
        self = <PyIOFile>opaque
        res = self.fread(buf_size)
        memcpy(buf, <void*><char*>res, len(res))
        self.pos += len(res)
        if not res:
            return lib.AVERROR_EOF
        return len(res)
    except Exception as e:
        return stash_exception()


cdef int pyio_write(void *opaque, const uint8_t *buf, int buf_size) noexcept nogil:
    with gil:
        return pyio_write_gil(opaque, buf, buf_size)

cdef int pyio_write_gil(void *opaque, const uint8_t *buf, int buf_size) noexcept:
    cdef PyIOFile self
    cdef bytes bytes_to_write
    cdef int bytes_written
    try:
        self = <PyIOFile>opaque
        bytes_to_write = buf[:buf_size]
        ret_value = self.fwrite(bytes_to_write)
        bytes_written = ret_value if isinstance(ret_value, int) else buf_size
        self.pos += bytes_written
        return bytes_written
    except Exception as e:
        return stash_exception()


cdef int64_t pyio_seek(void *opaque, int64_t offset, int whence) noexcept nogil:
    # Seek takes the standard flags, but also a ad-hoc one which means that
    # the library wants to know how large the file is. We are generally
    # allowed to ignore this.
    if whence == lib.AVSEEK_SIZE:
        return -1
    with gil:
        return pyio_seek_gil(opaque, offset, whence)

cdef int64_t pyio_seek_gil(void *opaque, int64_t offset, int whence):
    cdef PyIOFile self
    try:
        self = <PyIOFile>opaque
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


cdef int pyio_close_gil(lib.AVIOContext *pb):
    try:
        return lib.avio_close(pb)

    except Exception as e:
        stash_exception()


cdef int pyio_close_custom_gil(lib.AVIOContext *pb):
    cdef PyIOFile self
    try:
        self = <PyIOFile>pb.opaque

        # Flush bytes in the AVIOContext buffers to the custom I/O
        result = lib.avio_flush(pb)

        if self.fclose is not None:
            self.fclose()

        return 0

    except Exception as e:
        stash_exception()
