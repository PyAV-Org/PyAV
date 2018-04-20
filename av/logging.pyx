from __future__ import absolute_import

from libc.stdlib cimport malloc, free
from libc.stdio cimport printf, fprintf, stderr
from libc.string cimport strncmp, strcpy, memcpy
from cpython cimport pythread

cimport libav as lib

import logging
import sys


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


# While we start with the level quite low, Python defaults to INFO, and so
# they will not show. The logging system can add significant overhead, so
# be wary of dropping this lower.
cdef int _level_threshold = lib.AV_LOG_INFO

# ... but lets limit ourselves to WARNING immediately.
logging.getLogger('libav').setLevel(logging.WARNING)


def get_level():
    """Return current logging threshold. See :func:`set_level`."""
    return _level_threshold

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
    global _level_threshold
    _level_threshold = level


cdef bint _print_after_shutdown = False

def get_print_after_shutdown():
    """Will logging continue to ``stderr`` after Python shutdown?"""
    return _print_after_shutdown

def set_print_after_shutdown(v):
    """Set if logging should continue to ``stderr`` after Python shutdown."""
    global _print_after_shutdown
    _print_after_shutdown = bool(v)


cdef bint _skip_repeated = True

def get_skip_repeated():
    """Will identical logs be emitted?"""
    return _skip_repeated

def set_skip_repeated(v):
    """Set if identical logs will be emitted"""
    global _skip_repeated
    _skip_repeated = bool(v)


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

cdef pythread.PyThread_type_lock _queue_lock = pythread.PyThread_allocate_lock()
cdef pythread.PyThread_type_lock _skip_lock = pythread.PyThread_allocate_lock()

cdef struct _Record:
    const char *name
    int level
    char message[1024]
    _Record *next

cdef _Record *_queue_start = NULL
cdef _Record *_queue_end = NULL
cdef int _queue_size
cdef bint _print_queue_size = False

# For repeat check.
cdef _Record _last_record
cdef int _skip_count = 0


# For error reporting.
cdef _Record _last_error_record
cdef int _error_count = 0

cdef _get_last_error():
    """Get the (name, level, message) for the last error log."""
    if _error_count:
        # Manual locking FTW!
        if pythread.PyThread_acquire_lock(_skip_lock, 1): # 1 -> wait
            res = _error_count, (
                'libav.' + _last_error_record.name if _last_error_record.name else '',
                _last_error_record.level,
                _last_error_record.message if _last_error_record.message[0] else '',
            )
            pythread.PyThread_release_lock(_skip_lock)
        return res
    else:
        return 0, None


cdef bint _push_record(_Record *src) nogil:
    """Copies the given record, and puts it onto the queue."""

    global _queue_start, _queue_end, _queue_size
    if not pythread.PyThread_acquire_lock(_queue_lock, 1): # 1 -> wait
        return False

    cdef _Record *record = <_Record*>malloc(sizeof(_Record))
    memcpy(record, src, sizeof(_Record))
    record.next = NULL

    if _print_queue_size and _queue_size:
        if _queue_start == NULL:
            # I've never seen it get here.
            fprintf(stderr, "av.logging has lost %d records!\n", _queue_size)
        else:
            fprintf(stderr, "av.logging queued %d records\n", _queue_size)
    _queue_size += 1

    if _queue_start == NULL:
        _queue_start = record
    else:
        _queue_end.next = record
    _queue_end = record

    pythread.PyThread_release_lock(_queue_lock)
    return True

cdef bint _pop_record(_Record *dst):
    """Copies the first record on the queue to the given pointer."""

    global _queue_start, _queue_end, _queue_size
    if not pythread.PyThread_acquire_lock(_queue_lock, 1): # 1 -> wait
        return False

    cdef _Record *record = NULL
    if _queue_start:
        record = _queue_start
        _queue_start = record.next
        _queue_size -= 1

    pythread.PyThread_release_lock(_queue_lock)

    if record == NULL:
        return False

    # This free is what makes this whole copying thing worth it, since it
    # heavily simplifies a few of the lower functions, since their records can
    # be on the stack, and the queue functions fully deal with free-ing memory.
    # This has led to memory leaks in the past, so I'm okay with a little
    # wasted memory copying.
    memcpy(dst, record, sizeof(_Record))
    free(record)
    return True


cdef void log_callback(void *ptr, int level, const char *format, lib.va_list args) nogil:

    # We need to do everything with the `void *ptr` in this function, since
    # the object it represents may be freed by the time the async_log_callback
    # is run by Python.

    global _error_count
    global _skip_count

    cdef bint inited = lib.Py_IsInitialized()
    if not inited and not _print_after_shutdown:
        return

    cdef _Record record
    record.level = level
    lib.vsnprintf(record.message, 1023, format, args)

    # Get the name.
    cdef lib.AVClass *cls = (<lib.AVClass**>ptr)[0] if ptr else NULL
    cdef char *item_name = NULL;
    if cls and cls.item_name:
        # I'm not 100% on this, but this should be static, and so
        # it doesn't matter if the AVClass that returned it vanishes or not.
        record.name = cls.item_name(ptr)

    # We have to filter it ourselves, but we will still process it in general so
    # it is availible to our error handling.
    # Note that FFmpeg's levels are backwards from Python's.
    cdef bint is_interesting = level <= _level_threshold

    # Skip messages which are identical to the previous.
    cdef bint is_repeated = False
    if pythread.PyThread_acquire_lock(_skip_lock, 1): # 1 -> wait

        if is_interesting:

            is_repeated = (
                _skip_repeated and
                _last_record.message[0] and
                strncmp(_last_record.message, record.message, 1024) == 0
            )

            if is_repeated:
                _skip_count += 1

            elif _skip_count:
                # Now that we have hit the end of the repeat cycle, tally up how many.
                # We are both abusing the _last_record (assuming that the next message
                # won't also be about repeated messages), but also assuming that putting
                # the message onto the queue will get it seen.
                lib.snprintf(_last_record.message, 1023, "last message repeated %d times", _skip_count)
                _push_record(&_last_record)
                _skip_count = 0

            memcpy(&_last_record, &record, sizeof(_Record))

        # Hold onto errors for err_check.
        if level == lib.AV_LOG_ERROR:
            _error_count += 1
            memcpy(&_last_error_record, &record, sizeof(_Record))

        pythread.PyThread_release_lock(_skip_lock)

        if not is_interesting:
            return
        if is_repeated:
            return


    if inited and _push_record(&record):
        # Schedule this to be called in the main Python thread. This does not always
        # work, so a few logs might get delayed.
        lib.Py_AddPendingCall(<void*>async_log_callback, NULL)
    else:
        # After Python shutdown, or the lock did not acquire.
        fprintf(stderr, "av.logging: %s[%d]: %s",
            item_name, level, record.message
        )
        return


cdef int async_log_callback(void *arg) except -1:

    cdef int level
    cdef str logger_name
    cdef str item_name

    cdef _Record record
    cdef bint inited = lib.Py_IsInitialized()

    while _pop_record(&record):

        if inited:
            try:
                level = level_map.get(record.level, 20)
                item_name = record.name if record.name else ''
                logger_name = 'libav.' + item_name if item_name else 'libav.generic'
                logger = logging.getLogger(logger_name)
                logger.log(level, record.message.strip())
            except Exception as e:
                fprintf(stderr, "av.logging: exception while handling %s[%d]: %s",
                    record.name, record.level, record.message
                )
                # For some reason lib.PyErr_PrintEx(0) won't work.
                exc, type_, tb = sys.exc_info()
                lib.PyErr_Display(exc, type_, tb)

        elif _print_after_shutdown:
            fprintf(stderr, "av.logging: %s[%d]: %s",
                record.name, record.level, record.message
            )


    return 0


# Start the magic!
lib.av_log_set_callback(log_callback)
