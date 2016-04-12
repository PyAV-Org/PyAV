from __future__ import absolute_import

from libc.stdlib cimport malloc, free
from libc.stdio cimport printf, fprintf, stderr

cimport libav as lib

import logging
import sys


# Levels.
QUIET = lib.AV_LOG_QUIET
PANIC = lib.AV_LOG_PANIC
FATAL = lib.AV_LOG_FATAL
ERROR = lib.AV_LOG_ERROR
WARNING = lib.AV_LOG_WARNING
INFO = lib.AV_LOG_INFO
VERBOSE = lib.AV_LOG_VERBOSE
DEBUG = lib.AV_LOG_DEBUG


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


# While we start with the level quite low, Python defaults to INFO, and so
# they will not show.
cdef int log_level = lib.AV_LOG_VERBOSE

# ... but lets limit ourselves to WARNING immediately.
logging.getLogger('libav').setLevel(logging.WARNING)


def get_level():
    """Return current logging threshold. See :func:`set_level`."""
    return log_level

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
    global log_level
    log_level = level


cdef bint log_after_shutdown = False

def set_log_after_shutdown(v):
    """Set if logging should continue to ``stderr`` after Python shutdown."""
    global log_after_shutdown
    log_after_shutdown = v


# Threads sure are a mess!
#
# I simply did not find a way to capture the GIL in a function called from a
# thread that was spawned by Libav. The only solution is the tangle that you
# see before you.
#
# We handle the formatting of the log and extraction of the AVClass' item_name
# immediately, but stuff the resulting message and it's log level into a
# temporary struct. We use the super low-level Py_AddPendingCall to schedule a
# call to run in the main Python thread. That call dumps the message into the
# Python logging system.


cdef struct LogRequest:
    int level
    const char *item_name
    char message[1024]
    bint handled

cdef int count = 0
cdef LogRequest req


cdef void log_callback(void *ptr, int level, const char *format, lib.va_list args) nogil:

    # We have to filter it ourselves.
    # Note that FFmpeg's levels are backwards from Python's.
    if level > log_level:
        return

    cdef bint inited = lib.Py_IsInitialized()
    if not inited and not log_after_shutdown:
        return

    # We need to do everything with the `void *ptr` in this function, since
    # the object it represents may be freed by the time the async_log_callback
    # is run by Python.
    cdef lib.AVClass *cls = (<lib.AVClass**>ptr)[0] if ptr else NULL
    cdef char *item_name = NULL;
    if cls and cls.item_name:
        # I'm not 100% on this, but a `const char*` should be static, and so
        # it doesn't matter if the AVClass that returned it vanishes or not.
        item_name = cls.item_name(ptr)

    lib.vsnprintf(req.message, 1023, format, args)

    # This log came after Python shutdown.
    if not inited:
        fprintf(stderr, "av.logging: %s[%d]: %s",
            item_name, level, req.message
        )
        #free(message)
        return

    req.level = level
    req.item_name = item_name
    req.handled = 0

    # Schedule this to be called in the main Python thread. This does not always
    # work, so we might lose a few logs. Whoops.
    lib.Py_AddPendingCall(<void*>async_log_callback, NULL)

cdef int async_log_callback(void *arg) except -1:

    cdef int level
    cdef str logger_name
    cdef str item_name

    if req.handled:
        return 0
    req.handled = 1

    if lib.Py_IsInitialized():
        try:
            level = level_map.get(req.level, 20)
            item_name = req.item_name if req.item_name else ''
            logger_name = 'libav.' + item_name if item_name else 'libav.generic'
            logger = logging.getLogger(logger_name)
            logger.log(level, req.message.strip())
        except Exception as e:
            fprintf(stderr, "av.logging: exception while handling %s[%d]: %s",
                req.item_name, req.level, req.message
            )
            # For some reason lib.PyErr_PrintEx(0) won't work.
            exc, type_, tb = sys.exc_info()
            lib.PyErr_Display(exc, type_, tb)

    elif log_after_shutdown:
        fprintf(stderr, "av.logging: %s[%d]: %s",
            req.item_name, req.level, req.message
        )

    return 0


# Start the magic!
lib.av_log_set_callback(log_callback)
#lib.av_log_set_level(lib.AV_LOG_ERROR)
