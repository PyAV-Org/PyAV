
cimport libav as lib

from av.codec.codec cimport Codec


cdef class HWConfig(object):

    cdef object __weakref__

    cdef lib.AVCodecHWConfig *ptr

    cdef void _init(self, lib.AVCodecHWConfig *ptr)


cdef HWConfig wrap_hwconfig(lib.AVCodecHWConfig *ptr)


cdef class HWAccel(object):

    #cdef lib.AVHWAccel *ptr

    cdef str _device_type
    cdef str _device
    cdef public dict options

cdef class HWAccelContext(HWAccel):

    cdef readonly Codec codec
    cdef readonly HWConfig config

    cdef lib.AVBufferRef *ptr

