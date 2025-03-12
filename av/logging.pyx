"""
FFmpeg has a logging system that it uses extensively. It's very noisy so PyAV turns it
off by default. This, unfortunately has the effect of making raised errors having less
detailed messages. It's therefore recommended to use VERBOSE when developing.

.. _enable_logging:

Enabling Logging
~~~~~~~~~~~~~~~~~

You can hook the logging system with Python by setting the log level::

    import av

    av.logging.set_level(av.logging.VERBOSE)


PyAV hooks into that system to translate FFmpeg logs into Python's
`logging system <https://docs.python.org/3/library/logging.html#logging.basicConfig>`_.

If you are not already using Python's logging system, you can initialize it
quickly with::

    import logging
    logging.basicConfig()


Note that handling logs with Python sometimes doesn't play nice multi-threads workflows.
An alternative is :func:`restore_default_callback`.

This will restores FFmpeg's logging default system, which prints to the terminal.
Like with setting the log level to ``None``, this may also result in raised errors
having less detailed messages.


API Reference
~~~~~~~~~~~~~

"""

cimport libav as lib
from libc.stdio cimport fprintf, stderr
from libc.stdlib cimport free, malloc

import logging
import sys
from threading import Lock, get_ident

# Library levels.
PANIC = lib.AV_LOG_PANIC  # 0
FATAL = lib.AV_LOG_FATAL  # 8
ERROR = lib.AV_LOG_ERROR
WARNING = lib.AV_LOG_WARNING
INFO = lib.AV_LOG_INFO
VERBOSE = lib.AV_LOG_VERBOSE
DEBUG = lib.AV_LOG_DEBUG
TRACE = lib.AV_LOG_TRACE

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
    else:  # lib.AV_LOG_TRACE
        return 1


cdef object level_threshold = None

# ... but lets limit ourselves to WARNING (assuming nobody already did this).
if "libav" not in logging.Logger.manager.loggerDict:
    logging.getLogger("libav").setLevel(logging.WARNING)


def get_level():
    """Returns the current log level. See :func:`set_level`."""
    return level_threshold


def set_level(level):
    """set_level(level)

    Sets PyAV's log level. It can be set to constants available in this
    module: ``PANIC``, ``FATAL``, ``ERROR``, ``WARNING``, ``INFO``,
    ``VERBOSE``, ``DEBUG``, or ``None`` (the default).

    PyAV defaults to totally ignoring all ffmpeg logs. This has the side effect of
    making certain Exceptions have no messages. It's therefore recommended to use:

         av.logging.set_level(av.logging.VERBOSE)

    When developing your application.
    """
    global level_threshold

    if level is None:
        level_threshold = level
        lib.av_log_set_callback(nolog_callback)
    elif type(level) is int:
        level_threshold = level
        lib.av_log_set_callback(log_callback)
    else:
        raise ValueError("level must be: int | None")


def set_libav_level(level):
    """Set libav's log level.  It can be set to constants available in this
    module: ``PANIC``, ``FATAL``, ``ERROR``, ``WARNING``, ``INFO``,
    ``VERBOSE``, ``DEBUG``.

    When PyAV logging is disabled, setting this will change the level of
    the logs printed to the terminal.
    """
    lib.av_log_set_level(level)


def restore_default_callback():
    """Revert back to FFmpeg's log callback, which prints to the terminal."""
    lib.av_log_set_callback(lib.av_log_default_callback)


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

cdef class Capture:
    """A context manager for capturing logs.

    :param bool local: Should logs from all threads be captured, or just one
        this object is constructed in?

    e.g.::

        with Capture() as logs:
            # Do something.
        for log in logs:
            print(log.message)

    """

    cdef readonly list logs
    cdef list captures

    def __init__(self, bint local=True):
        self.logs = []

        if local:
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

cdef const char *log_context_name(void *ptr) noexcept nogil:
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
    cdef bytes message_bytes = message.encode("utf-8")

    lib.av_log(<void*>obj, level, "%s", <char*>message_bytes)
    free(obj)


cdef log_callback_gil(int level, const char *c_name, const char *c_message):
    global error_count
    global skip_count
    global last_log
    global last_error

    name = <str>c_name if c_name is not NULL else ""
    message = (<bytes>c_message).decode("utf8", "backslashreplace")
    log = (level, name, message)

    # We have to filter it ourselves, but we will still process it in general so
    # it is available to our error handling.
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

    logger_name = "libav." + name if name else "libav.generic"
    logger = logging.getLogger(logger_name)
    logger.log(py_level, message.strip())


cdef void log_callback(void *ptr, int level, const char *format, lib.va_list args) noexcept nogil:
    cdef bint inited = lib.Py_IsInitialized()
    if not inited:
        return

    with gil:
        if level > level_threshold and level != lib.AV_LOG_ERROR:
            return

    # Format the message.
    cdef char message[1024]
    lib.vsnprintf(message, 1023, format, args)

    # Get the name.
    cdef const char *name = NULL
    cdef lib.AVClass *cls = (<lib.AVClass**>ptr)[0] if ptr else NULL
    if cls and cls.item_name:
        name = cls.item_name(ptr)

    with gil:
        try:
            log_callback_gil(level, name, message)
        except Exception:
            fprintf(stderr, "av.logging: exception while handling %s[%d]: %s\n",
                    name, level, message)
            # For some reason lib.PyErr_PrintEx(0) won't work.
            exc, type_, tb = sys.exc_info()
            lib.PyErr_Display(exc, type_, tb)


cdef void nolog_callback(void *ptr, int level, const char *format, lib.va_list args) noexcept nogil:
    pass

lib.av_log_set_callback(nolog_callback)
