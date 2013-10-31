from __future__ import absolute_import

from cython.operator cimport dereference as deref
from libc.stdlib cimport malloc, free
from libc.stdint cimport uint8_t

cimport libav as lib

import logging


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
    return lib.av_log_get_level()

def set_level(int level):
    lib.av_log_set_level(level)


# Threads sure are a mess!
#
# I simply did not find a way to capture the GIL in a function called from a
# thread that was spawned by Libav. The only solution is the tangle that you
# see before you.
#
# We handle the formatting of the log immediately, but stuff the resultang
# message and it's log level into a temporary struct. We use the super low-level
# Py_AddPendingCall to schedule a call to run in the main Python thread. That
# call dumps the message into the Python logging system.


cdef struct LogRequest:
    void *ptr
    int level
    char message[1024]

cdef void log_callback(void *ptr, int level, const char *format, lib.va_list args) nogil:
    cdef LogRequest *req = <LogRequest*>malloc(sizeof(LogRequest))
    req.ptr = ptr
    req.level = level
    lib.vsnprintf(req.message, 1024, format, args)
    lib.Py_AddPendingCall(<void*>async_log_callback, <void*>req)

cdef int async_log_callback(void *arg) except -1:

    cdef LogRequest *req = <LogRequest*>arg
    cdef int py_level
    cdef str logger_name = 'libav.null'

    cdef lib.AVClass *cls = (<lib.AVClass**>req.ptr)[0] if req.ptr else NULL
    cdef char* c_item_name
    cdef bytes item_name

    try:

        py_level = level_map.get(req.level, 20)

        # We would do this sort of thing with FFmpeg's av_log_format_line, but
        # it doesn't exist in Libav.
        if cls and cls.item_name:
            c_item_name = cls.item_name(req.ptr)
            if c_item_name:
                item_name = c_item_name
                if item_name and item_name != "NULL":
                    logger_name = 'libav.' + item_name

        logging.getLogger(logger_name).log(py_level, req.message.strip())
        return 0

    finally:
        free(req)


# Start the magic!
lib.av_log_set_callback(log_callback)
