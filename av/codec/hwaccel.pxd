cimport libav as lib
from libc.stdbool cimport bool as c_bool


cdef class HWConfig:
    cdef object __weakref__
    cdef const lib.AVCodecHWConfig *ptr
    cdef void _init(self, const lib.AVCodecHWConfig *ptr)

cdef HWConfig wrap_hwconfig(const lib.AVCodecHWConfig *ptr)

cdef class HWDevice:
    cdef lib.AVBufferRef *ptr
    cdef readonly dict options
    cdef int _device_type
    cdef readonly int flags

cdef class HWAccel:
    cdef str _device
    cdef readonly HWConfig config
    cdef lib.AVBufferRef *ptr
    cdef public dict options
    cdef int _device_type
    cdef readonly int device_id
    cdef public int flags
    cdef readonly c_bool is_hw_owned
    cdef public c_bool allow_software_fallback
