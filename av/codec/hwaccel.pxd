
cimport libav as lib


cdef class HWConfig(object):

    cdef object __weakref__

    cdef lib.AVCodecHWConfig *ptr

    cdef void _init(self, lib.AVCodecHWConfig *ptr)


cdef HWConfig wrap_hwconfig(lib.AVCodecHWConfig *ptr)


cdef class HWAccel(object):

    cdef lib.AVHWAccel *ptr

    cdef str _device_type
    cdef str _device
    cdef public dict options
