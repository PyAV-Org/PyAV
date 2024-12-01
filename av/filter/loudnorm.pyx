# av/filter/loudnorm.pyx

cimport libav as lib
from cpython.bytes cimport PyBytes_FromString
from libc.stdlib cimport free

from av.audio.codeccontext cimport AudioCodecContext
from av.audio.stream cimport AudioStream
from av.container.core cimport Container
from av.stream cimport Stream
from av.logging import get_level, set_level


cdef extern from "libavcodec/avcodec.h":
    ctypedef struct AVCodecContext:
        pass

cdef extern from "libavformat/avformat.h":
    ctypedef struct AVFormatContext:
        pass

cdef extern from "loudnorm_impl.h":
    char* loudnorm_get_stats(
        AVFormatContext* fmt_ctx,
        int audio_stream_index,
        const char* loudnorm_args
    ) nogil


cpdef bytes stats(str loudnorm_args, AudioStream stream):
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

    cdef Container container = stream.container
    cdef AVFormatContext* format_ptr = container.ptr

    container.ptr = NULL  # Prevent double-free

    cdef int stream_index = stream.index
    cdef bytes py_args = loudnorm_args.encode("utf-8")
    cdef const char* c_args = py_args
    cdef char* result

    # Save log level since C function overwrite it.
    level = get_level()

    with nogil:
        result = loudnorm_get_stats(format_ptr, stream_index, c_args)

    if result == NULL:
        raise RuntimeError("Failed to get loudnorm stats")

    py_result = result[:]  # Make a copy of the string
    free(result)  # Free the C string

    set_level(level)

    return py_result
