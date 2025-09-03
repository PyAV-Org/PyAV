# type: ignore
from fractions import Fraction

import cython
from cython.cimports import libav as lib
from cython.cimports.av.error import err_check

# === DICTIONARIES ===
# ====================


@cython.cfunc
def _decode(s: cython.pointer[cython.char], encoding, errors) -> str:
    return cython.cast(bytes, s).decode(encoding, errors)


@cython.cfunc
def _encode(s, encoding, errors) -> bytes:
    return s.encode(encoding, errors)


@cython.cfunc
def avdict_to_dict(
    input: cython.pointer[lib.AVDictionary], encoding: str, errors: str
) -> dict:
    element: cython.pointer[lib.AVDictionaryEntry] = cython.NULL
    output: dict = {}
    while True:
        element = lib.av_dict_get(input, "", element, lib.AV_DICT_IGNORE_SUFFIX)
        if element == cython.NULL:
            break
        output[_decode(element.key, encoding, errors)] = _decode(
            element.value, encoding, errors
        )

    return output


@cython.cfunc
def dict_to_avdict(
    dst: cython.pointer[cython.pointer[lib.AVDictionary]],
    src: dict,
    encoding: str,
    errors: str,
):
    lib.av_dict_free(dst)
    for key, value in src.items():
        err_check(
            lib.av_dict_set(
                dst, key.encode(encoding, errors), value.encode(encoding, errors), 0
            )
        )


# === FRACTIONS ===
# =================


@cython.cfunc
def avrational_to_fraction(
    input: cython.pointer[cython.const[lib.AVRational]],
) -> object:
    if input.num and input.den:
        return Fraction(input.num, input.den)
    return None


@cython.cfunc
def to_avrational(frac: object, input: cython.pointer[lib.AVRational]) -> cython.void:
    input.num = frac.numerator
    input.den = frac.denominator


@cython.cfunc
def check_ndarray(array: object, dtype: object, ndim: cython.int) -> cython.void:
    """
    Check a numpy array has the expected data type and number of dimensions.
    """
    if array.dtype != dtype:
        raise ValueError(
            f"Expected numpy array with dtype `{dtype}` but got `{array.dtype}`"
        )
    if array.ndim != ndim:
        raise ValueError(
            f"Expected numpy array with ndim `{ndim}` but got `{array.ndim}`"
        )
