cimport libav as lib

from av.logging cimport get_last_error

from av.enums import define_enum

from threading import local
import errno
import os
import sys
import traceback


__all__ = ['AVError']  # Will only contain exception types.

cdef is_py3 = sys.version_info[0] >= 3
cdef is_py33 = sys.version_info >= (3, 3)


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
    atag = bytearray(tag)  # Python 2. Ugh.
    return (
        (atag[0]) +
        (atag[1] << 8) +
        (atag[2] << 16) +
        (atag[3] << 24)
    )


# Mimick the builtin exception types.
# See https://www.python.org/dev/peps/pep-3151/#new-exception-classes
# Use the named ones we have, otherwise default to OSError for anything in errno.
builtin_classes = {
    errno.EEXIST: FileExistsError,
    errno.ENOENT: FileNotFoundError,
    errno.EISDIR: IsADirectoryError,
    errno.ENOTDIR: NotADirectoryError,
    errno.EACCES: PermissionError,
    errno.EPERM: PermissionError,
    errno.EAGAIN: BlockingIOError,
    errno.EALREADY: BlockingIOError,
    errno.EWOULDBLOCK: BlockingIOError,
    errno.EINPROGRESS: BlockingIOError,
    errno.EPIPE: BrokenPipeError,
    errno.ESHUTDOWN: BrokenPipeError,
    errno.EINTR: InterruptedError,
    errno.ECONNABORTED: ConnectionAbortedError,
    errno.ECONNREFUSED: ConnectionRefusedError,
    errno.ECONNRESET: ConnectionResetError,
    errno.ETIMEDOUT: TimeoutError,
    errno.ECHILD: ChildProcessError,
    errno.ESRCH: ProcessLookupError,
} if is_py33 else {}
for code in errno.errorcode:
    builtin_classes.setdefault(code, OSError)


# Our custom error, used in callbacks.
cdef int c_PYAV_STASHED_ERROR = tag_to_code(b'PyAV')
cdef str PYAV_STASHED_ERROR_message = 'Error in PyAV callback'

ErrorType = define_enum("ErrorType", (

    ('BSF_NOT_FOUND', -lib.AVERROR_BSF_NOT_FOUND),
    ('BUG', -lib.AVERROR_BUG),
    ('BUFFER_TOO_SMALL', -lib.AVERROR_BUFFER_TOO_SMALL),
    ('DECODER_NOT_FOUND', -lib.AVERROR_DECODER_NOT_FOUND),
    ('DEMUXER_NOT_FOUND', -lib.AVERROR_DEMUXER_NOT_FOUND),
    ('ENCODER_NOT_FOUND', -lib.AVERROR_ENCODER_NOT_FOUND),
    ('EOF', -lib.AVERROR_EOF),
    ('EXIT', -lib.AVERROR_EXIT),
    ('EXTERNAL', -lib.AVERROR_EXTERNAL),
    ('FILTER_NOT_FOUND', -lib.AVERROR_FILTER_NOT_FOUND),
    ('INVALIDDATA', -lib.AVERROR_INVALIDDATA),
    ('MUXER_NOT_FOUND', -lib.AVERROR_MUXER_NOT_FOUND),
    ('OPTION_NOT_FOUND', -lib.AVERROR_OPTION_NOT_FOUND),
    ('PATCHWELCOME', -lib.AVERROR_PATCHWELCOME),
    ('PROTOCOL_NOT_FOUND', -lib.AVERROR_PROTOCOL_NOT_FOUND),
    ('UNKNOWN', -lib.AVERROR_UNKNOWN),
    ('EXPERIMENTAL', -lib.AVERROR_EXPERIMENTAL),
    ('INPUT_CHANGED', -lib.AVERROR_INPUT_CHANGED),
    ('OUTPUT_CHANGED', -lib.AVERROR_OUTPUT_CHANGED),
    ('HTTP_BAD_REQUEST', -lib.AVERROR_HTTP_BAD_REQUEST),
    ('HTTP_UNAUTHORIZED', -lib.AVERROR_HTTP_UNAUTHORIZED),
    ('HTTP_FORBIDDEN', -lib.AVERROR_HTTP_FORBIDDEN),
    ('HTTP_NOT_FOUND', -lib.AVERROR_HTTP_NOT_FOUND),
    ('HTTP_OTHER_4XX', -lib.AVERROR_HTTP_OTHER_4XX),
    ('HTTP_SERVER_ERROR', -lib.AVERROR_HTTP_SERVER_ERROR),

    # Our custom error.
    ('PYAV_CALLBACK', c_PYAV_STASHED_ERROR),

), allow_user_create=True)

ErrorType.tag = property(lambda self: code_to_tag(self.value))

# Define them globally as well to mimick `errno` module.
for enum in ErrorType:
    if enum.value == c_PYAV_STASHED_ERROR:
        enum.strerror = PYAV_STASHED_ERROR_message
    else:
        enum.strerror = lib.av_err2str(-enum.value)
    globals()[enum.name] = enum


class AVError(EnvironmentError):

    """Exception class for errors from within FFmpeg."""

    # Make it look like <av.Error ...>
    __module__ = 'av'

    def __init__(self, code, message, filename=None, log=None):

        if filename:
            super(AVError, self).__init__(code, message, filename)
        else:
            super(AVError, self).__init__(code, message)

        self.type = ErrorType.get(code, create=True)
        self.log = log

    def __str__(self):
        strerror = super(AVError, self).__str__()
        if self.log:
            return '%s (%s: %s)' % (strerror, self.log[0], self.log[1])
        else:
            return strerror


# Define a specific class for each.
classes = {}
cdef dict _error_class_names = {
    -lib.AVERROR_BSF_NOT_FOUND: 'BSFNotFound',
    -lib.AVERROR_EOF: 'EOFError',
    -lib.AVERROR_HTTP_OTHER_4XX: 'HTTPOther4XXError',
    -lib.AVERROR_HTTP_SERVER_ERROR: 'HTTPServerError',
    -lib.AVERROR_INVALIDDATA: 'InvalidDataError',
    -lib.AVERROR_PATCHWELCOME: 'PatchWelcomeError',
    c_PYAV_STASHED_ERROR: 'PyAVStashedError',  # This should never be seen.
}
for enum in ErrorType:
    name = _error_class_names.get(enum.value) or (
        enum.name.title().replace('Http_', 'HTTP_').replace('_', '') + 'Error'
    )
    cls = type(name, (AVError, ), {'__module__': 'av'})
    classes[enum.value] = cls  # av.error.classes[123] -> ExampleError
    globals()[name] = cls  # av.error.ExampleError
    __all__.append(name)  # av.ExampleError


cdef object _local = local()
cdef int _err_count = 0

cdef int stash_exception(exc_info=None):

    global _err_count

    existing = getattr(_local, 'exc_info', None)
    if existing is not None:
        print >> sys.stderr, 'PyAV library exception being dropped:'
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
        exc_info = getattr(_local, 'exc_info', None)
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


cpdef make_error(int res, filename=None, log=None):

    cdef int code = -res
    cdef bytes py_buffer
    cdef char *c_buffer

    # If it is one of the OSError classes, use that.
    cls = builtin_classes.get(code)
    if cls is not None:
        message = os.strerror(code)
        e = cls(code, message, filename)
        e.log = log  # Still add the log attr!
        return e

    if code == c_PYAV_STASHED_ERROR:
        message = PYAV_STASHED_ERROR_message

    else:
        py_buffer = b"\0" * lib.AV_ERROR_MAX_STRING_SIZE
        c_buffer = py_buffer
        lib.av_strerror(res, c_buffer, lib.AV_ERROR_MAX_STRING_SIZE)
        py_buffer = c_buffer

        # We want the native string type.
        message = py_buffer.decode('latin1') if is_py3 else py_buffer

    cls = classes.get(code, AVError)
    return cls(code, message, filename, log)
