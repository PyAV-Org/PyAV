# type: ignore
import cython
from cython.cimports import libav as lib
from cython.cimports.av.error import err_check


@cython.cfunc
def _decode(s: cython.pointer[cython.char]) -> str:
    return cython.cast(bytes, s).decode("utf-8", "surrogateescape")


@cython.cfunc
def avdict_to_dict(input: cython.pointer[lib.AVDictionary]) -> dict:
    element: cython.pointer[lib.AVDictionaryEntry] = cython.NULL
    output: dict = {}
    while True:
        element = lib.av_dict_get(input, "", element, lib.AV_DICT_IGNORE_SUFFIX)
        if element == cython.NULL:
            break
        output[_decode(element.key)] = _decode(element.value)

    return output


@cython.cfunc
def dict_to_avdict(
    dst: cython.pointer[cython.pointer[lib.AVDictionary]], src: dict
) -> cython.void:
    lib.av_dict_free(dst)
    for key, value in src.items():
        err_check(
            lib.av_dict_set(
                dst,
                key.encode("utf-8", "surrogateescape"),
                value.encode("utf-8", "surrogateescape"),
                0,
            )
        )


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
