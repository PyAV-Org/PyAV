import cython
from cython.cimports.av.audio.stream import AudioStream
from cython.cimports.av.container.core import Container
from cython.cimports.libc.stdlib import free

from av.logging import get_level, set_level


@cython.ccall
def stats(loudnorm_args: str, stream: AudioStream) -> bytes:
    """
    Get loudnorm statistics for an audio stream.

    Args:
        loudnorm_args (str): Arguments for the loudnorm filter (e.g. "i=-24.0:lra=7.0:tp=-2.0")
        stream (AudioStream): Input audio stream to analyze

    Returns:
        bytes: JSON string containing the loudnorm statistics
    """

    if "print_format=json" not in loudnorm_args:
        loudnorm_args = loudnorm_args + ":print_format=json"

    container: Container = stream.container
    format_ptr: cython.pointer[AVFormatContext] = container.ptr
    container.ptr = cython.NULL  # Prevent double-free

    stream_index: cython.int = stream.index
    py_args: bytes = loudnorm_args.encode("utf-8")
    c_args: cython.p_const_char = py_args
    result: cython.p_char

    # Save log level since C function overwrite it.
    level = get_level()

    with cython.nogil:
        result = loudnorm_get_stats(format_ptr, stream_index, c_args)

    if result == cython.NULL:
        raise RuntimeError("Failed to get loudnorm stats")

    py_result = result[:]  # Make a copy of the string
    free(result)  # Free the C string

    set_level(level)

    return py_result
