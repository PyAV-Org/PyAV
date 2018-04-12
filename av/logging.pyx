from __future__ import absolute_import

from libc.stdlib cimport malloc, free
from libc.stdio cimport printf, fprintf, stderr
from libc.string cimport strncmp, strcpy, memcpy
from cpython cimport pythread
from cpython cimport pystate


cimport libav as lib

import logging
import sys
from threading import Lock, get_ident


# Levels.
QUIET = lib.AV_LOG_QUIET # -8
PANIC = lib.AV_LOG_PANIC # 0
FATAL = lib.AV_LOG_FATAL # 8
ERROR = lib.AV_LOG_ERROR
WARNING = lib.AV_LOG_WARNING
INFO = lib.AV_LOG_INFO
VERBOSE = lib.AV_LOG_VERBOSE
DEBUG = lib.AV_LOG_DEBUG
#TRACE = lib.AV_LOG_TRACE # 56 # Does not exist in ffmpeg <= 2.2.4.


# Map from AV levels to logging levels.
level_map = {
    # lib.AV_LOG_QUIET is not actually a level.
    lib.AV_LOG_PANIC: 50,   # logging.CRITICAL
    lib.AV_LOG_FATAL: 50,   # logging.CRITICAL
    lib.AV_LOG_ERROR: 40,   # logging.ERROR
    lib.AV_LOG_WARNING: 30, # logging.WARNING
    lib.AV_LOG_INFO: 20,    # logging.INFO
    lib.AV_LOG_VERBOSE: 10, # logging.DEBUG
    lib.AV_LOG_DEBUG: 5,    # This is below any logging constant.
}


cpdef adapt_level(int lib_level):
    """Convert a library log level to a Python log level."""
    py_level = level_map.get(lib_level)
    if py_level is None:
        while py_level is None and lib_level < lib.AV_LOG_DEBUG:
            lib_level += 1
            py_level = level_map.get(lib_level)
        level_map[lib_level] = py_level
    return py_level


# While we start with the level quite low, Python defaults to INFO, and so
# they will not show. The logging system can add significant overhead, so
# be wary of dropping this lower.
cdef int level_threshold = lib.AV_LOG_INFO

# ... but lets limit ourselves to WARNING immediately.
if 'libav' not in logging.Logger.manager.loggerDict:
    logging.getLogger('libav').setLevel(logging.WARNING)


def get_level():
    """Return current logging threshold. See :func:`set_level`."""
    return level_threshold

def set_level(int level):
    """set_level(level)

    Sets logging threshold when converting from the library's logging system
    to Python's. It is recommended to use the constants availible in this
    module to set the level: ``QUIET``, ``PANIC``, ``FATAL``, ``ERROR``,
    ``WARNING``, ``INFO``, ``VERBOSE``, and ``DEBUG``.

    While less efficient, it is generally preferable to modify logging
    with Python's :mod:`logging`, e.g.::

        logging.getLogger('libav').setLevel(logging.ERROR)

    PyAV defaults to translating everything except ``AV_LOG_DEBUG``, so this
    function is only nessesary to use if you want to see those messages as well.
    ``AV_LOG_DEBUG`` will be translated to a level 5 message, which is lower
    than any builting Python logging level, so you must lower that as well::

        logging.getLogger().setLevel(5)

    """
    global level_threshold
    level_threshold = level


cdef bint print_after_shutdown = False

def get_print_after_shutdown():
    """Will logging continue to ``stderr`` after Python shutdown?"""
    return print_after_shutdown

def set_print_after_shutdown(v):
    """Set if logging should continue to ``stderr`` after Python shutdown."""
    global print_after_shutdown
    print_after_shutdown = bool(v)


cdef bint skip_repeated = True
cdef skip_lock = Lock()
cdef object last_log = None
cdef int skip_count = 0

def get_skip_repeated():
    """Will identical logs be emitted?"""
    return skip_repeated

def set_skip_repeated(v):
    """Set if identical logs will be emitted"""
    global skip_repeated
    skip_repeated = bool(v)


# For error reporting.
cdef object last_error = None
cdef int error_count = 0

cdef _get_last_error():
    """Get the (level, name, message) for the last error log."""
    if error_count:
        with skip_lock:
            res = error_count, (
                last_error[0],
                'libav.' + last_error[1] if last_error[1] else '',
                last_error[2] or '',
            )
        return res
    else:
        return 0, None


cdef default_captures = []
cdef threaded_captures = {}

cdef class Capture(object):

    cdef readonly bint threaded
    cdef readonly list records
    cdef list captures

    def __init__(self, threaded=True):
        self.threaded = threaded
        self.records = []
        if self.threaded:
            self.captures = threaded_captures.setdefault(get_ident(), [])
        else:
            self.captures = default_captures

    def __enter__(self):
        self.captures.append(self.records)
        return self.records

    def __exit__(self, type_, value, traceback):
        self.captures.pop(-1)




cdef void log_callback(void *ptr, int level, const char *format, lib.va_list args) nogil:

    cdef bint inited = lib.Py_IsInitialized()
    if not inited and not print_after_shutdown:
        return

    # Format the message.
    cdef char message[1024]
    lib.vsnprintf(message, 1023, format, args)

    # Get the name.
    cdef char *name = NULL
    cdef lib.AVClass *cls = (<lib.AVClass**>ptr)[0] if ptr else NULL
    if cls and cls.item_name:
        # I'm not 100% on this, but this should be static, and so
        # it doesn't matter if the AVClass that returned it vanishes or not.
        name = cls.item_name(ptr)

    if not inited:
        fprintf(stderr, "av.logging (after shutdown): %s[%d]: %s\n",
            name, level, message,
        )
        return


    with gil:

        try:
            log_callback_gil(level, name, message)

        except Exception as e:
            fprintf(stderr, "av.logging: exception while handling %s[%d]: %s",
                name, level, message,
            )
            # For some reason lib.PyErr_PrintEx(0) won't work.
            exc, type_, tb = sys.exc_info()
            lib.PyErr_Display(exc, type_, tb)


cdef log_callback_gil(int level, const char *c_name, const char *c_message):

    global error_count
    global skip_count
    global last_log
    global last_error

    name = <str>c_name if c_name is not NULL else ''
    message = (<bytes>c_message).decode('utf8', 'backslashreplace')
    log = (level, name, message)

    # We have to filter it ourselves, but we will still process it in general so
    # it is availible to our error handling.
    # Note that FFmpeg's levels are backwards from Python's.
    cdef bint is_interesting = level <= level_threshold

    # Skip messages which are identical to the previous.
    # TODO: Be smarter about threads.
    cdef bint is_repeated = False
    with skip_lock:

        if is_interesting:

            is_repeated = skip_repeated and last_log == log

            if is_repeated:
                skip_count += 1

            elif skip_count:
                # Now that we have hit the end of the repeat cycle, tally up how many.
                repeat_log = (last_log[0], last_log[1], "%s (repeated %d times)" % (last_log[2], skip_count))
                emit_log(repeat_log)
                skip_count = 0

            last_log = log

        # Hold onto errors for err_check.
        if level == lib.AV_LOG_ERROR:
            error_count += 1
            last_error = log

        if not is_interesting:
            return
        if is_repeated:
            return

        emit_log(log)


cdef emit_log(log):

    lib_level, name, message = log

    captures = threaded_captures.get(get_ident()) or default_captures
    if captures:
        captures[-1].append(log)
        return

    py_level = adapt_level(lib_level)

    logger_name = 'libav.' + name if name else 'libav.generic'
    logger = logging.getLogger(logger_name)
    logger.log(py_level, message.strip())



# Start the magic!
lib.av_log_set_callback(log_callback)
