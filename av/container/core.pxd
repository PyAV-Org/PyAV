cimport libav as lib

from av.container.streams cimport StreamContainer
from av.dictionary cimport _Dictionary
from av.format cimport ContainerFormat
from av.stream cimport Stream


cdef class Container(object):

    cdef readonly bint writeable
    cdef lib.AVFormatContext *ptr

    cdef readonly object name
    cdef readonly str metadata_encoding
    cdef readonly str metadata_errors

    # File-like source.
    cdef readonly object file
    cdef object fread
    cdef object fwrite
    cdef object fseek
    cdef object ftell

    # Custom IO for above.
    cdef lib.AVIOContext *iocontext
    cdef unsigned char *buffer
    cdef long pos
    cdef bint pos_is_valid
    cdef bint input_was_opened

    cdef readonly ContainerFormat format

    cdef readonly dict options
    cdef readonly dict container_options
    cdef readonly list stream_options

    cdef dict hwaccel

    cdef readonly StreamContainer streams
    cdef readonly dict metadata

    cdef int err_check(self, int value) except -1
