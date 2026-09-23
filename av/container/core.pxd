cimport libav as lib
from libc.stdint cimport uint8_t

from av.codec.hwaccel cimport HWAccel
from av.container.pyio cimport PyIOFile
from av.container.streams cimport StreamContainer
from av.dictionary cimport Dictionary
from av.format cimport ContainerFormat
from av.stream cimport Stream

# Interrupt callback information, times are in seconds.
ctypedef struct timeout_info:
    double start_time
    double timeout


cdef class Container:
    cdef lib.AVFormatContext *ptr
    cdef readonly str name
    cdef readonly PyIOFile file
    cdef readonly object io_open
    cdef readonly dict open_files
    cdef readonly ContainerFormat format
    cdef readonly dict options
    cdef readonly dict container_options
    cdef dict _metadata
    cdef readonly StreamContainer streams
    cdef readonly object open_timeout
    cdef readonly object read_timeout

    cdef HWAccel hwaccel

    cdef timeout_info interrupt_callback_info
    cdef int buffer_size
    cdef uint8_t _myflag  # enum: writeable, input_was_opened, started, done, extradata_planned

    cdef void _assert_open(self)
    cdef void set_timeout(self, object)
    cdef void start_timeout(self)
    cdef int err_check(self, int value) except -1
