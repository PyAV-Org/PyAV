cimport libav as lib

from av.stream cimport Stream

from .core cimport Container


cdef class StreamContainer:
    cdef list _streams

    # For the different types.
    cdef readonly tuple video
    cdef readonly tuple audio
    cdef readonly tuple subtitles
    cdef readonly tuple attachments
    cdef readonly tuple data
    cdef readonly tuple other

    cdef add_stream(self, Stream stream)
    cdef int _get_best_stream_index(self, Container container, lib.AVMediaType type_enum, Stream related) noexcept

