cimport libav as lib

from av.logging cimport get_last_error

from threading import local
import sys
import traceback


# Would love to use the built-in constant, but it doesn't appear to
# exist on Travis, or my Linux workstation. Could this be because they
# are actually libav?
cdef int AV_ERROR_MAX_STRING_SIZE = 64

# Our custom error.
cdef int PYAV_ERROR = -0x50794156  # 'PyAV'


class AVError(EnvironmentError):
    """Exception class for errors from within FFmpeg."""
    def __init__(self, code, message, filename=None, log=None):
        if filename:
            super(AVError, self).__init__(code, message, filename)
        else:
            super(AVError, self).__init__(code, message)
        self.log = log

    def __str__(self):
        strerror = super(AVError, self).__str__()
        if self.log:
            return '%s (%s: %s)' % (strerror, self.log[0], self.log[1])
        else:
            return strerror


AVError.__module__ = 'av'


cdef object _local = local()
cdef int _err_count = 0

cdef int stash_exception(exc_info=None):

    global _err_count

    existing = getattr(_local, 'exc_info', None)
    if existing is not None:
        print >> sys.stderr, 'PyAV library exception being dropped:'
        traceback.print_exception(*existing)
        _err_count -= 1

    exc_info = exc_info or sys.exc_info()
    _local.exc_info = exc_info
    if exc_info:
        _err_count += 1

    return PYAV_ERROR


cdef int _last_log_count = 0

cpdef int err_check(int res=0, filename=None) except -1:

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

    cdef bytes py_buffer
    cdef char *c_buffer

    if res == PYAV_ERROR:
        py_buffer = b'Error in PyAV callback'

    else:
        # This is kinda gross.
        py_buffer = b"\0" * AV_ERROR_MAX_STRING_SIZE
        c_buffer = py_buffer
        lib.av_strerror(res, c_buffer, AV_ERROR_MAX_STRING_SIZE)
        py_buffer = c_buffer
    cdef unicode message = py_buffer.decode('latin1')

    # Add details from the last log onto the end.
    log_count, last_log = get_last_error()
    if log_count > _last_log_count:
        _last_log_count = log_count
        log = last_log
    else:
        log = None

    if filename:
        raise AVError(-res, message, filename, log)
    else:
        raise AVError(-res, message, None, log)

