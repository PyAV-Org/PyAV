from __future__ import absolute_import

from libc.stdlib cimport malloc, free
from libc.stdio cimport printf, fprintf, stderr, snprintf

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
    lib.AV_LOG_QUIET: 0,
    lib.AV_LOG_PANIC: 50,
    lib.AV_LOG_FATAL: 50,
    lib.AV_LOG_ERROR: 40,
    lib.AV_LOG_WARNING: 30,
    lib.AV_LOG_INFO: 20,
    lib.AV_LOG_VERBOSE: 10,
    lib.AV_LOG_DEBUG: 0,
}


def get_level():
    """Return current logging threshold."""
    return lib.av_log_get_level()

def set_level(int level):
    """set_level(level)

    Set logging threshold."""
    lib.av_log_set_level(level)

cdef bint log_after_shutdown = False

def set_log_after_shutdown(v):
    """Set if logging should continue after Python shutdown."""
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
    char *message

cdef void log_callback(void *ptr, int level, const char *format, lib.va_list args) nogil:

    cdef LogRequest *req = <LogRequest*>malloc(sizeof(LogRequest))
    req.level = level
    req.item_name = NULL

    # We need to do everything with the `void *ptr` in this function, since
    # the object it represents may be freed by the time the async_log_callback
    # is run by Python.
    cdef lib.AVClass *cls = (<lib.AVClass**>ptr)[0] if ptr else NULL
    if cls and cls.item_name:
        # I'm not 100% on this, but a `const char*` should be static, and so
        # it doesn't matter if the AVClass that returned it vanishes or not.
        req.item_name = cls.item_name(ptr)

    # Use the library's formatting functions (which are cross platform).
    cdef lib.AVBPrint buf
    lib.av_bprint_init(&buf, 0, -1);
    lib.av_vbprintf(&buf, format, args);
    lib.av_bprint_finalize(&buf, &req.message);

    if not req.message:
        # Assume that the format has a trailing newline.
        printf("av.logging: av_vbprintf errored on %s: %s", req.item_name, format)
        free(req)
        return

    # Schedule this to be called in the main Python thread, but only if
    # Python hasn't started finalizing yet.
    if lib.Py_IsInitialized():
        lib.Py_AddPendingCall(<void*>async_log_callback, <void*>req)
    elif log_after_shutdown:
        fprintf(stderr, "av.logging: %s[%d]: %s",
            req.item_name, req.level, req.message
        )
        free(req.message)
        free(req)


cdef int async_log_callback(void *arg) except -1:

    cdef LogRequest *req = <LogRequest*>arg
    cdef int level
    cdef str logger_name
    cdef str item_name

    if not lib.Py_IsInitialized():
        if log_after_shutdown:
            fprintf(stderr, "av.logging: %s[%d]: %s",
                req.item_name, req.level, req.message
            )
        return 0

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
    finally:
        free(req.message)
        free(req)

    return 0


# Start the magic!
lib.av_log_set_callback(log_callback)
