from __future__ import absolute_import

from libc.stdlib cimport malloc, free
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
    int level
    char message[1024]

cdef void log_callback(void *obj, int level, const char *format, lib.va_list args) nogil:
    cdef int print_prefix = 1
    cdef LogRequest *req = <LogRequest*>malloc(sizeof(LogRequest))
    req.level = level
    lib.av_log_format_line(obj, level, format, args, req.message, 1024, &print_prefix)
    lib.Py_AddPendingCall(<void*>async_log_callback, <void*>req)

cdef int async_log_callback(void *arg) except -1:
    cdef LogRequest *req = <LogRequest*>arg
    cdef int py_level
    try:
        py_level = level_map.get(req.level, 20)
        logging.getLogger('av').log(py_level, req.message.strip())
        return 0
    finally:
        free(req)


# Start the magic!
lib.av_log_set_callback(log_callback)
