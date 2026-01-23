import errno
import os
import sys
import traceback
from threading import local

import cython
from cython.cimports import libav as lib
from cython.cimports.av.logging import get_last_error
from cython.cimports.libc.stdio import fprintf, stderr
from cython.cimports.libc.stdlib import free, malloc

# Will get extended with all of the exceptions.
__all__ = [
    "ErrorType",
    "FFmpegError",
    "LookupError",
    "HTTPError",
    "HTTPClientError",
    "UndefinedError",
]
sentinel = cython.declare(object, object())


@cython.ccall
def code_to_tag(code: cython.int) -> bytes:
    """Convert an integer error code into 4-byte tag.

    >>> code_to_tag(1953719668)
    b'test'

    """
    return bytes(
        (
            code & 0xFF,
            (code >> 8) & 0xFF,
            (code >> 16) & 0xFF,
            (code >> 24) & 0xFF,
        )
    )


@cython.ccall
def tag_to_code(tag: bytes) -> cython.int:
    """Convert a 4-byte error tag into an integer code.

    >>> tag_to_code(b'test')
    1953719668

    """
    if len(tag) != 4:
        raise ValueError("Error tags are 4 bytes.")
    return (tag[0]) + (tag[1] << 8) + (tag[2] << 16) + (tag[3] << 24)


class FFmpegError(Exception):
    """Exception class for errors from within FFmpeg.

    .. attribute:: errno

        FFmpeg's integer error code.

    .. attribute:: strerror

        FFmpeg's error message.

    .. attribute:: filename

        The filename that was being operated on (if available).

    .. attribute:: log

        The tuple from :func:`av.logging.get_last_log`, or ``None``.

    """

    def __init__(self, code, message, filename=None, log=None):
        self.errno = code
        self.strerror = message

        args = [code, message]
        if filename or log:
            args.append(filename)
            if log:
                args.append(log)
        super().__init__(*args)
        self.args = tuple(args)

    @property
    def filename(self):
        try:
            return self.args[2]
        except IndexError:
            pass

    @property
    def log(self):
        try:
            return self.args[3]
        except IndexError:
            pass

    def __str__(self):
        msg = ""
        if self.errno is not None:
            msg = f"{msg}[Errno {self.errno}] "
        if self.strerror is not None:
            msg = f"{msg}{self.strerror}"
        if self.filename:
            msg = f"{msg}: {self.filename!r}"
        if self.log:
            msg = (
                f"{msg}; last error log: [{self.log[1].strip()}] {self.log[2].strip()}"
            )

        return msg


# Our custom error, used in callbacks.
c_PYAV_STASHED_ERROR: cython.int = tag_to_code(b"PyAV")
PYAV_STASHED_ERROR_message: str = "Error in PyAV callback"


# Bases for the FFmpeg-based exceptions.
class LookupError(FFmpegError, LookupError):
    pass


class HTTPError(FFmpegError):
    pass


class HTTPClientError(FFmpegError):
    pass


# Tuples of (enum_name, enum_value, exc_name, exc_base).
# tuple[str, int, str | None, Exception | none]
# fmt: off
_ffmpeg_specs = (
    ("BSF_NOT_FOUND", -lib.AVERROR_BSF_NOT_FOUND, "BSFNotFoundError", LookupError),
    ("BUG", -lib.AVERROR_BUG, None, RuntimeError),
    ("BUFFER_TOO_SMALL", -lib.AVERROR_BUFFER_TOO_SMALL, None, ValueError),
    ("DECODER_NOT_FOUND", -lib.AVERROR_DECODER_NOT_FOUND, None, LookupError),
    ("DEMUXER_NOT_FOUND", -lib.AVERROR_DEMUXER_NOT_FOUND, None, LookupError),
    ("ENCODER_NOT_FOUND", -lib.AVERROR_ENCODER_NOT_FOUND, None, LookupError),
    ("EOF", -lib.AVERROR_EOF, "EOFError", EOFError),
    ("EXIT", -lib.AVERROR_EXIT, None, None),
    ("EXTERNAL", -lib.AVERROR_EXTERNAL, None, None),
    ("FILTER_NOT_FOUND", -lib.AVERROR_FILTER_NOT_FOUND, None, LookupError),
    ("INVALIDDATA", -lib.AVERROR_INVALIDDATA, "InvalidDataError", ValueError),
    ("MUXER_NOT_FOUND", -lib.AVERROR_MUXER_NOT_FOUND, None, LookupError),
    ("OPTION_NOT_FOUND", -lib.AVERROR_OPTION_NOT_FOUND, None, LookupError),
    ("PATCHWELCOME", -lib.AVERROR_PATCHWELCOME, "PatchWelcomeError", None),
    ("PROTOCOL_NOT_FOUND", -lib.AVERROR_PROTOCOL_NOT_FOUND, None, LookupError),
    ("UNKNOWN", -lib.AVERROR_UNKNOWN, None, None),
    ("EXPERIMENTAL", -lib.AVERROR_EXPERIMENTAL, None, None),
    ("INPUT_CHANGED", -lib.AVERROR_INPUT_CHANGED, None, None),
    ("OUTPUT_CHANGED", -lib.AVERROR_OUTPUT_CHANGED, None, None),
    ("HTTP_BAD_REQUEST", -lib.AVERROR_HTTP_BAD_REQUEST, "HTTPBadRequestError", HTTPClientError),
    ("HTTP_UNAUTHORIZED", -lib.AVERROR_HTTP_UNAUTHORIZED, "HTTPUnauthorizedError", HTTPClientError),
    ("HTTP_FORBIDDEN", -lib.AVERROR_HTTP_FORBIDDEN, "HTTPForbiddenError", HTTPClientError),
    ("HTTP_NOT_FOUND", -lib.AVERROR_HTTP_NOT_FOUND, "HTTPNotFoundError", HTTPClientError),
    ("HTTP_OTHER_4XX", -lib.AVERROR_HTTP_OTHER_4XX, "HTTPOtherClientError", HTTPClientError),
    ("HTTP_SERVER_ERROR", -lib.AVERROR_HTTP_SERVER_ERROR, "HTTPServerError", HTTPError),
    ("PYAV_CALLBACK", c_PYAV_STASHED_ERROR, "PyAVCallbackError", RuntimeError),
)
# fmt: on


class EnumType(type):
    def __new__(mcl, name, bases, attrs, *args):
        # Just adapting the method signature.
        return super().__new__(mcl, name, bases, attrs)

    def __init__(self, name, bases, attrs, items):
        self._by_name = {}
        self._by_value = {}
        self._all = []

        for spec in items:
            self._create(*spec)

    def _create(self, name, value, doc=None, by_value_only=False):
        # We only have one instance per value.
        try:
            item = self._by_value[value]
        except KeyError:
            item = self(sentinel, name, value, doc)
            self._by_value[value] = item

        return item

    def __len__(self):
        return len(self._all)

    def __iter__(self):
        return iter(self._all)


@cython.cclass
class EnumItem:
    """An enumeration of FFmpeg's error types.

    .. attribute:: tag

        The FFmpeg byte tag for the error.

    .. attribute:: strerror

        The error message that would be returned.
    """

    name = cython.declare(str, visibility="readonly")
    value = cython.declare(cython.int, visibility="readonly")

    def __cinit__(self, sentinel_, name: str, value: cython.int, doc=None):
        if sentinel_ is not sentinel:
            raise RuntimeError(f"Cannot instantiate {self.__class__.__name__}.")

        self.name = name
        self.value = value
        self.__doc__ = doc

    def __repr__(self):
        return f"<{self.__class__.__module__}.{self.__class__.__name__}:{self.name}(0x{self.value:x})>"

    def __str__(self):
        return self.name

    def __int__(self):
        return self.value

    @property
    def tag(self):
        return code_to_tag(self.value)


ErrorType = EnumType(
    "ErrorType", (EnumItem,), {"__module__": __name__}, [x[:2] for x in _ffmpeg_specs]
)


for enum in ErrorType:
    # Mimick the errno module.
    globals()[enum.name] = enum
    if enum.value == c_PYAV_STASHED_ERROR:
        enum.strerror = PYAV_STASHED_ERROR_message
    else:
        enum.strerror = lib.av_err2str(-enum.value)

classes: dict = {}


def _extend_builtin(name, codes):
    base = getattr(__builtins__, name, OSError)
    cls = type(name, (FFmpegError, base), {"__module__": __name__})

    # Register in builder.
    for code in codes:
        classes[code] = cls

    # Register in module.
    globals()[name] = cls
    __all__.append(name)

    return cls


_extend_builtin("PermissionError", (errno.EACCES, errno.EPERM))
_extend_builtin(
    "BlockingIOError",
    (errno.EAGAIN, errno.EALREADY, errno.EINPROGRESS, errno.EWOULDBLOCK),
)
_extend_builtin("ChildProcessError", (errno.ECHILD,))
_extend_builtin("ConnectionAbortedError", (errno.ECONNABORTED,))
_extend_builtin("ConnectionRefusedError", (errno.ECONNREFUSED,))
_extend_builtin("ConnectionResetError", (errno.ECONNRESET,))
_extend_builtin("FileExistsError", (errno.EEXIST,))
_extend_builtin("InterruptedError", (errno.EINTR,))
_extend_builtin("IsADirectoryError", (errno.EISDIR,))
_extend_builtin("FileNotFoundError", (errno.ENOENT,))
_extend_builtin("NotADirectoryError", (errno.ENOTDIR,))
_extend_builtin("BrokenPipeError", (errno.EPIPE, errno.ESHUTDOWN))
_extend_builtin("ProcessLookupError", (errno.ESRCH,))
_extend_builtin("TimeoutError", (errno.ETIMEDOUT,))
_extend_builtin("MemoryError", (errno.ENOMEM,))
_extend_builtin("NotImplementedError", (errno.ENOSYS,))
_extend_builtin("OverflowError", (errno.ERANGE,))
_extend_builtin("OSError", [code for code in errno.errorcode if code not in classes])


class ArgumentError(FFmpegError, ValueError):
    def __str__(self):
        msg = ""
        if self.strerror is not None:
            msg = f"{msg}{self.strerror}"
        if self.filename:
            msg = f"{msg}: {self.filename!r}"
        if self.errno is not None:
            msg = f"{msg} returned {self.errno}"
        if self.log:
            msg = (
                f"{msg}; last error log: [{self.log[1].strip()}] {self.log[2].strip()}"
            )

        return msg


class UndefinedError(FFmpegError):
    """Fallback exception type in case FFmpeg returns an error we don't know about."""

    pass


classes[errno.EINVAL] = ArgumentError
globals()["ArgumentError"] = ArgumentError
__all__.append("ArgumentError")


# Classes for the FFmpeg errors.
for enum_name, code, name, base in _ffmpeg_specs:
    name = name or enum_name.title().replace("_", "") + "Error"

    if base is None:
        bases = (FFmpegError,)
    elif issubclass(base, FFmpegError):
        bases = (base,)
    else:
        bases = (FFmpegError, base)

    cls = type(name, bases, {"__module__": __name__})

    # Register in builder.
    classes[code] = cls

    # Register in module.
    globals()[name] = cls
    __all__.append(name)

del _ffmpeg_specs


# Storage for stashing.
_local: object = local()
_err_count: cython.int = 0


@cython.cfunc
def stash_exception(exc_info=None) -> cython.int:
    global _err_count

    existing = getattr(_local, "exc_info", None)
    if existing is not None:
        fprintf(stderr, "PyAV library exception being dropped:\n")
        traceback.print_exception(*existing)
        _err_count -= 1  # Balance out the +=1 that is coming.

    exc_info = exc_info or sys.exc_info()
    _local.exc_info = exc_info
    if exc_info:
        _err_count += 1

    return -c_PYAV_STASHED_ERROR


_last_log_count: cython.int = 0


@cython.ccall
@cython.exceptval(-1, check=False)
def err_check(res: cython.int, filename=None) -> cython.int:
    """Raise appropriate exceptions from library return code."""

    global _err_count
    global _last_log_count

    # Check for stashed exceptions.
    if _err_count:
        exc_info = getattr(_local, "exc_info", None)
        if exc_info is not None:
            _err_count -= 1
            _local.exc_info = None
            raise exc_info[1].with_traceback(exc_info[2])

    if res >= 0:
        return res

    # Grab details from the last log.
    log_count, last_log = get_last_error()
    if log_count > _last_log_count:
        _last_log_count = log_count
        log = last_log
    else:
        log = None

    code: cython.int = -res
    error_buffer: cython.p_char = cython.cast(
        cython.p_char, malloc(lib.AV_ERROR_MAX_STRING_SIZE * cython.sizeof(char))
    )
    if error_buffer == cython.NULL:
        raise MemoryError()

    try:
        if code == c_PYAV_STASHED_ERROR:
            message = PYAV_STASHED_ERROR_message
        else:
            lib.av_strerror(res, error_buffer, lib.AV_ERROR_MAX_STRING_SIZE)
            # Fallback to OS error string if no message
            message = error_buffer or os.strerror(code)

        cls = classes.get(code, UndefinedError)
        raise cls(code, message, filename, log)
    finally:
        free(error_buffer)
