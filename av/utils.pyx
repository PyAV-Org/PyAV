from libc.stdint cimport uint64_t

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
        err_check(
            lib.av_dict_set(
                dst,
                _encode(key, encoding, errors),
                _encode(value, encoding, errors),
                0
            )
        )


# === FRACTIONS ===
# =================

cdef object avrational_to_fraction(const lib.AVRational *input):
    if input.num and input.den:
        return Fraction(input.num, input.den)


cdef void to_avrational(object frac, lib.AVRational *input):
    input.num = frac.numerator
    input.den = frac.denominator


# === OTHER ===
# =============


cdef check_ndarray(object array, object dtype, int ndim):
    """
    Check a numpy array has the expected data type and number of dimensions.
    """
    if array.dtype != dtype:
        raise ValueError(f"Expected numpy array with dtype `{dtype}` but got `{array.dtype}`")
    if array.ndim != ndim:
        raise ValueError(f"Expected numpy array with ndim `{ndim}` but got `{array.ndim}`")


cdef flag_in_bitfield(uint64_t bitfield, uint64_t flag):
    # Not every flag exists in every version of FFMpeg, so we define them to 0.
    if not flag:
        return None
    return bool(bitfield & flag)


# === BACKWARDS COMPAT ===

from .error import err_check
