cimport libav as lib

from av.logging cimport get_last_error

import errno
import os
import sys
import traceback
from threading import local

from av.enum import define_enum

# Will get extended with all of the exceptions.
__all__ = [
    "ErrorType", "FFmpegError", "LookupError", "HTTPError", "HTTPClientError",
    "UndefinedError",
]


cpdef code_to_tag(int code):
    """Convert an integer error code into 4-byte tag.

    >>> code_to_tag(1953719668)
    b'test'

    """
    return bytes((
        code & 0xff,
        (code >> 8) & 0xff,
        (code >> 16) & 0xff,
        (code >> 24) & 0xff,
    ))

cpdef tag_to_code(bytes tag):
    """Convert a 4-byte error tag into an integer code.

    >>> tag_to_code(b'test')
    1953719668

    """
    if len(tag) != 4:
        raise ValueError("Error tags are 4 bytes.")
    return (
        (tag[0]) +
        (tag[1] << 8) +
        (tag[2] << 16) +
        (tag[3] << 24)
    )


class FFmpegError(Exception):
    """Exception class for errors from within FFmpeg.

    .. attribute:: errno

        FFmpeg's integer error code.

    .. attribute:: strerror

        FFmpeg's error message.

    .. attribute:: filename

        The filename that was being operated on (if available).

    .. attribute:: type

        The :class:`av.error.ErrorType` enum value for the error type.

    .. attribute:: log

        The tuple from :func:`av.logging.get_last_log`, or ``None``.

    """

    def __init__(self, code, message, filename=None, log=None):
        args = [code, message]
        if filename or log:
            args.append(filename)
            if log:
                args.append(log)
        super(FFmpegError, self).__init__(*args)
        self.args = tuple(args)  # FileNotFoundError/etc. only pulls 2 args.
        self.type = ErrorType.get(code, create=True)

    @property
    def errno(self):
        return self.args[0]

    @property
    def strerror(self):
        return self.args[1]

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
        msg = f"[Errno {self.errno}] {self.strerror}"

        if self.filename:
            msg = f"{msg}: {self.filename!r}"

        if self.log:
            msg = f"{msg}; last error log: [{self.log[1].strip()}] {self.log[2].strip()}"

        return msg


# Our custom error, used in callbacks.
cdef int c_PYAV_STASHED_ERROR = tag_to_code(b"PyAV")
cdef str PYAV_STASHED_ERROR_message = "Error in PyAV callback"


# Bases for the FFmpeg-based exceptions.
class LookupError(FFmpegError, LookupError):
    pass


class HTTPError(FFmpegError):
    pass


class HTTPClientError(FFmpegError):
    pass


# Tuples of (enum_name, enum_value, exc_name, exc_base).
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


# The actual enum.
ErrorType = define_enum("ErrorType", __name__, [x[:2] for x in _ffmpeg_specs])

# It has to be monkey-patched.
ErrorType.__doc__ = """An enumeration of FFmpeg's error types.

.. attribute:: tag

    The FFmpeg byte tag for the error.

.. attribute:: strerror

    The error message that would be returned.

"""
ErrorType.tag = property(lambda self: code_to_tag(self.value))


for enum in ErrorType:
    # Mimick the errno module.
    globals()[enum.name] = enum
    if enum.value == c_PYAV_STASHED_ERROR:
        enum.strerror = PYAV_STASHED_ERROR_message
    else:
        enum.strerror = lib.av_err2str(-enum.value)


# Mimick the builtin exception types.
# See https://www.python.org/dev/peps/pep-3151/#new-exception-classes
# Use the named ones we have, otherwise default to OSError for anything in errno.

# See this command for the count of POSIX codes used:
#
#    egrep -IR 'AVERROR\(E[A-Z]+\)' vendor/ffmpeg-4.2 |\
#        sed -E 's/.*AVERROR\((E[A-Z]+)\).*/\1/' | \
#        sort | uniq -c
#
# The biggest ones that don't map to PEP 3151 builtins:
#
#    2106 EINVAL -> ValueError
#     649 EIO    -> IOError (if it is distinct from OSError)
#    4080 ENOMEM -> MemoryError
#     340 ENOSYS -> NotImplementedError
#      35 ERANGE -> OverflowError

classes = {}


def _extend_builtin(name, codes):
    base = getattr(__builtins__, name, OSError)
    cls = type(name, (FFmpegError, base), dict(__module__=__name__))

    # Register in builder.
    for code in codes:
        classes[code] = cls

    # Register in module.
    globals()[name] = cls
    __all__.append(name)

    return cls


# PEP 3151 builtins.
_extend_builtin("PermissionError", (errno.EACCES, errno.EPERM))
_extend_builtin("BlockingIOError", (errno.EAGAIN, errno.EALREADY, errno.EINPROGRESS, errno.EWOULDBLOCK))
_extend_builtin("ChildProcessError", (errno.ECHILD, ))
_extend_builtin("ConnectionAbortedError", (errno.ECONNABORTED, ))
_extend_builtin("ConnectionRefusedError", (errno.ECONNREFUSED, ))
_extend_builtin("ConnectionResetError", (errno.ECONNRESET, ))
_extend_builtin("FileExistsError", (errno.EEXIST, ))
_extend_builtin("InterruptedError", (errno.EINTR, ))
_extend_builtin("IsADirectoryError", (errno.EISDIR, ))
_extend_builtin("FileNotFoundError", (errno.ENOENT, ))
_extend_builtin("NotADirectoryError", (errno.ENOTDIR, ))
_extend_builtin("BrokenPipeError", (errno.EPIPE, errno.ESHUTDOWN))
_extend_builtin("ProcessLookupError", (errno.ESRCH, ))
_extend_builtin("TimeoutError", (errno.ETIMEDOUT, ))

# Other obvious ones.
_extend_builtin("ValueError", (errno.EINVAL, ))
_extend_builtin("MemoryError", (errno.ENOMEM, ))
_extend_builtin("NotImplementedError", (errno.ENOSYS, ))
_extend_builtin("OverflowError", (errno.ERANGE, ))

# The rest of them (for now)
_extend_builtin("OSError", [code for code in errno.errorcode if code not in classes])

# Classes for the FFmpeg errors.
for enum_name, code, name, base in _ffmpeg_specs:
    name = name or enum_name.title().replace("_", "") + "Error"

    if base is None:
        bases = (FFmpegError, )
    elif issubclass(base, FFmpegError):
        bases = (base, )
    else:
        bases = (FFmpegError, base)

    cls = type(name, bases, dict(__module__=__name__))

    # Register in builder.
    classes[code] = cls

    # Register in module.
    globals()[name] = cls
    __all__.append(name)


# Storage for stashing.
cdef object _local = local()
cdef int _err_count = 0

cdef int stash_exception(exc_info=None):
    global _err_count

    existing = getattr(_local, "exc_info", None)
    if existing is not None:
        print >> sys.stderr, "PyAV library exception being dropped:"
        traceback.print_exception(*existing)
        _err_count -= 1  # Balance out the +=1 that is coming.

    exc_info = exc_info or sys.exc_info()
    _local.exc_info = exc_info
    if exc_info:
        _err_count += 1

    return -c_PYAV_STASHED_ERROR


cdef int _last_log_count = 0

cpdef int err_check(int res, filename=None) except -1:
    """Raise appropriate exceptions from library return code."""

    global _err_count
    global _last_log_count

    # Check for stashed exceptions.
    if _err_count:
        exc_info = getattr(_local, "exc_info", None)
        if exc_info is not None:
            _err_count -= 1
            _local.exc_info = None
            raise exc_info[0], exc_info[1], exc_info[2]

    if res >= 0:
        return res

    # Grab details from the last log.
    log_count, last_log = get_last_error()
    if log_count > _last_log_count:
        _last_log_count = log_count
        log = last_log
    else:
        log = None

    raise make_error(res, filename, log)


class UndefinedError(FFmpegError):
    """Fallback exception type in case FFmpeg returns an error we don't know about."""
    pass


cpdef make_error(int res, filename=None, log=None):
    cdef int code = -res
    cdef bytes py_buffer
    cdef char *c_buffer

    if code == c_PYAV_STASHED_ERROR:
        message = PYAV_STASHED_ERROR_message
    else:
        # Jump through some hoops due to Python 2 in same codebase.
        py_buffer = b"\0" * lib.AV_ERROR_MAX_STRING_SIZE
        c_buffer = py_buffer
        lib.av_strerror(res, c_buffer, lib.AV_ERROR_MAX_STRING_SIZE)
        py_buffer = c_buffer
        message = py_buffer.decode("latin1")

        # Default to the OS if we have no message; this should not get called.
        message = message or os.strerror(code)

    cls = classes.get(code, UndefinedError)
    return cls(code, message, filename, log)
