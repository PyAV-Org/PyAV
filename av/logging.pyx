from __future__ import absolute_import

from libc.stdio cimport printf, fprintf, stderr
from libc.stdlib cimport malloc, free

cimport libav as lib

from threading import Lock
import logging
import sys

try:
    from threading import get_ident
except ImportError:
    from thread import get_ident


cdef bint is_py35 = sys.version_info[:2] >= (3, 5)
cdef str decode_error_handler = 'backslashreplace' if is_py35 else 'replace'


# Library levels.
# QUIET  = lib.AV_LOG_QUIET # -8; not really a level.
PANIC = lib.AV_LOG_PANIC  # 0
FATAL = lib.AV_LOG_FATAL  # 8
ERROR = lib.AV_LOG_ERROR
WARNING = lib.AV_LOG_WARNING
INFO = lib.AV_LOG_INFO
VERBOSE = lib.AV_LOG_VERBOSE
DEBUG = lib.AV_LOG_DEBUG
# TRACE  = lib.AV_LOG_TRACE # 56 # Does not exist in ffmpeg <= 2.2.4.

# Mimicking stdlib.
CRITICAL = FATAL


cpdef adapt_level(int level):
    """Convert a library log level to a Python log level."""

    if level <= lib.AV_LOG_FATAL:  # Includes PANIC
        return 50  # logging.CRITICAL
    elif level <= lib.AV_LOG_ERROR:
        return 40  # logging.ERROR
    elif level <= lib.AV_LOG_WARNING:
        return 30  # logging.WARNING
    elif level <= lib.AV_LOG_INFO:
        return 20  # logging.INFO
    elif level <= lib.AV_LOG_VERBOSE:
        return 10  # logging.DEBUG
    elif level <= lib.AV_LOG_DEBUG:
        return 5  # Lower than any logging constant.
    else:
        return 1  # ... yeah.


# While we start with the level quite low, Python defaults to INFO, and so
# they will not show. The logging system can add significant overhead, so
# be wary of dropping this lower.
cdef int level_threshold = lib.AV_LOG_VERBOSE

# ... but lets limit ourselves to WARNING (assuming nobody already did this).
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

cpdef get_last_error():
    """Get the last log that was at least ``ERROR``."""
    if error_count:
        with skip_lock:
            return error_count, last_error
    else:
        return 0, None


cdef global_captures = []
cdef thread_captures = {}

cdef class Capture(object):

    """Context manager for capturing logs.

    :param bool local: Should logs from all threads be captured, or just one
        this object is constructed in?

    e.g.::

        with Capture() as logs:
            # Do something.
        for log in logs:
            print(log.message)

    """

    cdef readonly bint local
    cdef readonly list logs
    cdef list captures

    def __init__(self, local=True):

        self.local = local
        self.logs = []

        if self.local:
            self.captures = thread_captures.setdefault(get_ident(), [])
        else:
            self.captures = global_captures

    def __enter__(self):
        self.captures.append(self.logs)
        return self.logs

    def __exit__(self, type_, value, traceback):
        self.captures.pop(-1)


cdef struct log_context:
    lib.AVClass *class_
    const char *name

cdef const char *log_context_name(void *ptr) nogil:
    cdef log_context *obj = <log_context*>ptr
    return obj.name

cdef lib.AVClass log_class
log_class.item_name = log_context_name

cpdef log(int level, str name, str message):
    """Send a log through the library logging system.

    This is mostly for testing.

    """

    cdef log_context *obj = <log_context*>malloc(sizeof(log_context))
    obj.class_ = &log_class
    obj.name = name
    lib.av_log(<void*>obj, level, "%s", message)
    free(obj)


cdef void log_callback(void *ptr, int level, const char *format, lib.va_list args) nogil:

    cdef bint inited = lib.Py_IsInitialized()
    if not inited and not print_after_shutdown:
        return

    # Format the message.
    cdef char message[1024]
    lib.vsnprintf(message, 1023, format, args)

    # Get the name.
    cdef const char *name = NULL
    cdef lib.AVClass *cls = (<lib.AVClass**>ptr)[0] if ptr else NULL
    if cls and cls.item_name:
        # I'm not 100% on this, but this should be static, and so
        # it doesn't matter if the AVClass that returned it vanishes or not.
        name = cls.item_name(ptr)

    if not inited:
        fprintf(stderr, "av.logging (after shutdown): %s[%d]: %s\n",
                name, level, message)
        return

    with gil:

        try:
            log_callback_gil(level, name, message)

        except Exception as e:
            fprintf(stderr, "av.logging: exception while handling %s[%d]: %s\n",
                    name, level, message)
            # For some reason lib.PyErr_PrintEx(0) won't work.
            exc, type_, tb = sys.exc_info()
            lib.PyErr_Display(exc, type_, tb)


cdef log_callback_gil(int level, const char *c_name, const char *c_message):

    global error_count
    global skip_count
    global last_log
    global last_error

    name = <str>c_name if c_name is not NULL else ''
    message = (<bytes>c_message).decode('utf8', decode_error_handler)
    log = (level, name, message)

    # We have to filter it ourselves, but we will still process it in general so
    # it is availible to our error handling.
    # Note that FFmpeg's levels are backwards from Python's.
    cdef bint is_interesting = level <= level_threshold

    # Skip messages which are identical to the previous.
    # TODO: Be smarter about threads.
    cdef bint is_repeated = False

    cdef object repeat_log = None

    with skip_lock:

        if is_interesting:

            is_repeated = skip_repeated and last_log == log

            if is_repeated:
                skip_count += 1

            elif skip_count:
                # Now that we have hit the end of the repeat cycle, tally up how many.
                if skip_count == 1:
                    repeat_log = last_log
                else:
                    repeat_log = (
                        last_log[0],
                        last_log[1],
                        "%s (repeated %d more times)" % (last_log[2], skip_count)
                    )
                skip_count = 0

            last_log = log

        # Hold onto errors for err_check.
        if level == lib.AV_LOG_ERROR:
            error_count += 1
            last_error = log

    if repeat_log is not None:
        log_callback_emit(repeat_log)

    if is_interesting and not is_repeated:
        log_callback_emit(log)


cdef log_callback_emit(log):

    lib_level, name, message = log

    captures = thread_captures.get(get_ident()) or global_captures
    if captures:
        captures[-1].append(log)
        return

    py_level = adapt_level(lib_level)

    logger_name = 'libav.' + name if name else 'libav.generic'
    logger = logging.getLogger(logger_name)
    logger.log(py_level, message.strip())


# Start the magic!
lib.av_log_set_callback(log_callback)
