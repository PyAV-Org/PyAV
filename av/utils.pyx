from libc.stdint cimport int64_t, uint8_t, uint64_t

from fractions import Fraction
from threading import local
import sys
import traceback

cimport libav as lib

from av.logging cimport get_last_error


# === ERROR HANDLING ===
# ======================

# Would love to use the built-in constant, but it doesn't appear to
# exist on Travis, or my Linux workstation. Could this be because they
# are actually libav?
cdef int AV_ERROR_MAX_STRING_SIZE = 64

# Our custom error.
cdef int PYAV_ERROR = -0x50794156 # 'PyAV'


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
        raise AVError(-res, message, None,     log)



# === DICTIONARIES ===
# ====================

cdef _decode(char *s, encoding, errors):
    return (<bytes>s).decode(encoding, errors)

cdef bytes _encode(s, encoding, errors):
    if isinstance(s, unicode):
        return s.encode(encoding, errors)
    return s

cdef dict avdict_to_dict(lib.AVDictionary *input, str encoding=None, str errors='strict'):
    if encoding is None:
        encoding = 'utf8'

    cdef lib.AVDictionaryEntry *element = NULL
    cdef dict output = {}
    while True:
        element = lib.av_dict_get(input, "", element, lib.AV_DICT_IGNORE_SUFFIX)
        if element == NULL:
            break
        output[_decode(element.key, encoding, errors)] = _decode(element.value, encoding, errors)
    return output


cdef dict_to_avdict(lib.AVDictionary **dst, dict src, bint clear=True, str encoding=None, str errors='strict'):
    if clear:
        lib.av_dict_free(dst)
    if encoding is None:
        encoding = 'utf8'
    for key, value in src.items():
        err_check(lib.av_dict_set(dst, _encode(key, encoding, errors),
                                  _encode(value, encoding, errors), 0))



# === FRACTIONS ===
# =================

cdef object avrational_to_fraction(const lib.AVRational *input):
    if input.num and input.den:
        return Fraction(input.num, input.den)


cdef object to_avrational(object value, lib.AVRational *input):

    if value is None:
        input.num = 0
        input.den = 1
        return

    if isinstance(value, Fraction):
        frac = value
    else:
        frac = Fraction(value)

    input.num = frac.numerator
    input.den = frac.denominator


# === OTHER ===
# =============

cdef flag_in_bitfield(uint64_t bitfield, uint64_t flag):
    # Not every flag exists in every version of FFMpeg, so we define them to 0.
    if not flag:
        return None
    return bool(bitfield & flag)
