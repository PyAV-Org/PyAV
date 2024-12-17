cimport libav as lib

from av.codec.codec cimport Codec


cdef class HWConfig:
    cdef object __weakref__
    cdef lib.AVCodecHWConfig *ptr
    cdef void _init(self, lib.AVCodecHWConfig *ptr)

cdef HWConfig wrap_hwconfig(lib.AVCodecHWConfig *ptr)

cdef class HWAccel:
    cdef int _device_type
    cdef str _device
    cdef readonly Codec codec
    cdef readonly HWConfig config
    cdef lib.AVBufferRef *ptr
    cdef public bint allow_software_fallback
    cdef public dict options
