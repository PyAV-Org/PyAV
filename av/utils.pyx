from libc.stdint cimport int64_t, uint8_t, uint64_t

from fractions import Fraction

cimport libav as lib

from av.error cimport err_check


# === DICTIONARIES ===
# ====================

cdef _decode(char *s, encoding, errors):
    return (<bytes>s).decode(encoding, errors)

cdef bytes _encode(s, encoding, errors):
    return s.encode(encoding, errors)

cdef dict avdict_to_dict(lib.AVDictionary *input, str encoding, str errors):
    cdef lib.AVDictionaryEntry *element = NULL
    cdef dict output = {}
    while True:
        element = lib.av_dict_get(input, "", element, lib.AV_DICT_IGNORE_SUFFIX)
        if element == NULL:
            break
        output[_decode(element.key, encoding, errors)] = _decode(element.value, encoding, errors)
    return output


cdef dict_to_avdict(lib.AVDictionary **dst, dict src, str encoding, str errors):
    lib.av_dict_free(dst)
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


# === BACKWARDS COMPAT ===

from .error import FFmpegError as AVError
from .error import err_check
