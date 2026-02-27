# type: ignore
import cython
from cython import NULL
from cython.cimports import libav as lib
from cython.cimports.av.error import stash_exception
from cython.cimports.libc.stdint import int64_t, uint8_t
from cython.cimports.libc.string import memcpy

Buf = cython.typedef(cython.pointer[uint8_t])
BufC = cython.typedef(cython.pointer[cython.const[uint8_t]])

seek_func_t = cython.typedef(
    "int64_t (*seek_func_t)(void *opaque, int64_t offset, int whence) noexcept nogil"
)


@cython.cclass
class PyIOFile:
    def __cinit__(self, file, buffer_size, writeable=None):
        self.file = file

        seek_func: seek_func_t = NULL

        readable = getattr(self.file, "readable", None)
        writable = getattr(self.file, "writable", None)
        seekable = getattr(self.file, "seekable", None)
        self.fread = getattr(self.file, "read", None)
        self.fwrite = getattr(self.file, "write", None)
        self.fseek = getattr(self.file, "seek", None)
        self.ftell = getattr(self.file, "tell", None)
        self.fclose = getattr(self.file, "close", None)

        # To be seekable, the file object must have `seek` and `tell` methods.
        # If it also has a `seekable` method, it must return True.
        if (
            self.fseek is not None
            and self.ftell is not None
            and (seekable is None or seekable())
        ):
            seek_func: seek_func_t = pyio_seek

        if writeable is None:
            writeable = self.fwrite is not None

        if writeable:
            if self.fwrite is None or (writable is not None and not writable()):
                raise ValueError(
                    "File object has no write() method, or writable() returned False."
                )
        else:
            if self.fread is None or (readable is not None and not readable()):
                raise ValueError(
                    "File object has no read() method, or readable() returned False."
                )

        self.pos = 0
        self.pos_is_valid = True

        # This is effectively the maximum size of reads.
        self.buffer = cython.cast(cython.p_uchar, lib.av_malloc(buffer_size))

        self.iocontext = lib.avio_alloc_context(
            self.buffer,
            buffer_size,
            writeable,
            cython.cast(cython.p_void, self),  # User data.
            pyio_read,
            pyio_write,
            seek_func,
        )

        if seek_func:
            self.iocontext.seekable = lib.AVIO_SEEKABLE_NORMAL
        self.iocontext.max_packet_size = buffer_size

    def __dealloc__(self):
        with cython.nogil:
            # FFmpeg will not release custom input, so it's up to us to free it.
            # Do not touch our original buffer as it may have been freed and replaced.
            if self.iocontext:
                lib.av_freep(cython.address(self.iocontext.buffer))
                lib.av_freep(cython.address(self.iocontext))

            # We likely errored badly if we got here, and so we are still responsible.
            else:
                lib.av_freep(cython.address(self.buffer))


@cython.cfunc
@cython.nogil
@cython.exceptval(check=False)
def pyio_read(opaque: cython.p_void, buf: Buf, buf_size: cython.int) -> cython.int:
    with cython.gil:
        return pyio_read_gil(opaque, buf, buf_size)


@cython.cfunc
@cython.exceptval(check=False)
def pyio_read_gil(opaque: cython.p_void, buf: Buf, buf_size: cython.int) -> cython.int:
    self: PyIOFile
    res: bytes
    try:
        self = cython.cast(PyIOFile, opaque)
        res = self.fread(buf_size)
        memcpy(
            buf, cython.cast(cython.p_void, cython.cast(cython.p_char, res)), len(res)
        )
        self.pos += len(res)
        if not res:
            return lib.AVERROR_EOF
        return len(res)
    except Exception:
        return stash_exception()


@cython.cfunc
@cython.nogil
@cython.exceptval(check=False)
def pyio_write(opaque: cython.p_void, buf: BufC, buf_size: cython.int) -> cython.int:
    with cython.gil:
        return pyio_write_gil(opaque, buf, buf_size)


@cython.cfunc
@cython.exceptval(check=False)
def pyio_write_gil(
    opaque: cython.p_void, buf: BufC, buf_size: cython.int
) -> cython.int:
    self: PyIOFile
    bytes_to_write: bytes
    bytes_written: cython.int
    try:
        self = cython.cast(PyIOFile, opaque)
        bytes_to_write = buf[:buf_size]
        ret_value = self.fwrite(bytes_to_write)
        bytes_written = ret_value if isinstance(ret_value, int) else buf_size
        self.pos += bytes_written
        return bytes_written
    except Exception:
        return stash_exception()


@cython.cfunc
@cython.nogil
@cython.exceptval(check=False)
def pyio_seek(opaque: cython.p_void, offset: int64_t, whence: cython.int) -> int64_t:
    # Seek takes the standard flags, but also a ad-hoc one which means that the library
    # wants to know how large the file is. We are generally allowed to ignore this.
    if whence == lib.AVSEEK_SIZE:
        return -1
    with cython.gil:
        return pyio_seek_gil(opaque, offset, whence)


@cython.cfunc
def pyio_seek_gil(
    opaque: cython.p_void, offset: int64_t, whence: cython.int
) -> int64_t:
    self: PyIOFile
    try:
        self = cython.cast(PyIOFile, opaque)
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
    except Exception:
        return stash_exception()


@cython.cfunc
def pyio_close_gil(pb: cython.pointer[lib.AVIOContext]) -> cython.int:
    try:
        return lib.avio_close(pb)
    except Exception:
        return stash_exception()


@cython.cfunc
def pyio_close_custom_gil(pb: cython.pointer[lib.AVIOContext]) -> cython.int:
    self: PyIOFile
    try:
        self = cython.cast(PyIOFile, pb.opaque)

        # Flush bytes in the AVIOContext buffers to the custom I/O
        lib.avio_flush(pb)

        if self.fclose is not None:
            self.fclose()

        return 0
    except Exception:
        stash_exception()
