from __future__ import print_function

import weakref

cimport libav as lib

from av.codec.codec cimport Codec
from av.enums cimport define_enum
from av.video.format cimport get_video_format


HWDeviceType = define_enum('HWDeviceType', (
    # ('NONE', lib.AV_HWDEVICE_TYPE_NONE),
    ('VDPAU', lib.AV_HWDEVICE_TYPE_VDPAU),
    ('CUDA', lib.AV_HWDEVICE_TYPE_CUDA),
    ('VAAPI', lib.AV_HWDEVICE_TYPE_VAAPI),
    ('DXVA2', lib.AV_HWDEVICE_TYPE_DXVA2),
    ('QSV', lib.AV_HWDEVICE_TYPE_QSV),
    ('VIDEOTOOLBOX', lib.AV_HWDEVICE_TYPE_VIDEOTOOLBOX),
    ('D3D11VA', lib.AV_HWDEVICE_TYPE_D3D11VA),
    ('DRM', lib.AV_HWDEVICE_TYPE_DRM),
    ('OPENCL', lib.AV_HWDEVICE_TYPE_OPENCL),
    ('MEDIACODEC', lib.AV_HWDEVICE_TYPE_MEDIACODEC),
))


HWConfigMethod = define_enum('HWConfigMethod', (
    ('NONE', 0),
    ('HW_DEVICE_CTX', lib.AV_CODEC_HW_CONFIG_METHOD_HW_DEVICE_CTX),  # This is the only one we support.
    ('HW_FRAMES_CTX', lib.AV_CODEC_HW_CONFIG_METHOD_HW_FRAMES_CTX),
    ('INTERNAL', lib.AV_CODEC_HW_CONFIG_METHOD_INTERNAL),
    ('AD_HOC', lib.AV_CODEC_HW_CONFIG_METHOD_AD_HOC),
), is_flags=True, allow_multi_flags=True)


cdef object _cinit_sentinel = object()
cdef object _singletons = weakref.WeakValueDictionary()

cdef HWConfig wrap_hwconfig(lib.AVCodecHWConfig *ptr):
    try:
        return _singletons[<int>ptr]
    except KeyError:
        pass
    cdef HWConfig config = HWConfig(_cinit_sentinel)
    config._init(ptr)
    _singletons[<int>ptr] = config
    return config


cdef class HWConfig(object):

    def __init__(self, sentinel):
        if sentinel is not _cinit_sentinel:
            raise RuntimeError('Cannot instantiate CodecContext')

    cdef void _init(self, lib.AVCodecHWConfig *ptr):
        self.ptr = ptr

    def __repr__(self):
        return (
            f'<av.{self.__class__.__name__} '
            f'device={self.device_type} '
            f'format={self.format.name if self.format else None} '
            f'is_supported={self.is_supported} '
            f'at 0x{<int>self.ptr:x}>'
        )

    @property
    def device_type(self):
        return HWDeviceType.get(self.ptr.device_type)

    @property
    def format(self):
        return get_video_format(self.ptr.pix_fmt, 0, 0)

    @property
    def methods(self):
        return HWConfigMethod.get(self.ptr.methods)

    @property
    def is_supported(self):
        return bool(self.ptr.methods & lib.AV_CODEC_HW_CONFIG_METHOD_HW_DEVICE_CTX)


hwdevices_availible = set()

cdef lib.AVHWDeviceType x = lib.AV_HWDEVICE_TYPE_NONE
while True:
    x = lib.av_hwdevice_iterate_types(x)
    if x == lib.AV_HWDEVICE_TYPE_NONE:
        break
    hwdevices_availible.add(HWDeviceType.get(x))


def dump_hwdevices():
    print('Hardware devices:')
    for x in hwdevices_availible:
        print('   ', x)


cdef class HWAccel(object):

    def __init__(self, device_type=None, device=None, options=None, **kwargs):

        self._device_type = device_type
        self._device = device

        if options and kwargs:
            raise ValueError("accepts only one of options arg or kwargs")
        self.options = dict(options or kwargs)

