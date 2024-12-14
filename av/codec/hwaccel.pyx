from __future__ import print_function

import weakref
from enum import IntEnum

cimport libav as lib

from av.codec.codec cimport Codec
from av.dictionary cimport _Dictionary
from av.error cimport err_check
from av.video.format cimport get_video_format

from av.dictionary import Dictionary


class Capabilities(IntEnum):
    none = 0
    draw_horiz_band = lib.AV_CODEC_CAP_DRAW_HORIZ_BAND
    dr1 = lib.AV_CODEC_CAP_DR1
    hwaccel = 1 << 4
    delay = lib.AV_CODEC_CAP_DELAY
    small_last_frame = lib.AV_CODEC_CAP_SMALL_LAST_FRAME
    hwaccel_vdpau = 1 << 7
    subframes = lib.AV_CODEC_CAP_SUBFRAMES
    experimental = lib.AV_CODEC_CAP_EXPERIMENTAL
    channel_conf = lib.AV_CODEC_CAP_CHANNEL_CONF
    neg_linesizes = 1 << 11
    frame_threads = lib.AV_CODEC_CAP_FRAME_THREADS
    slice_threads = lib.AV_CODEC_CAP_SLICE_THREADS
    param_change = lib.AV_CODEC_CAP_PARAM_CHANGE
    auto_threads = lib.AV_CODEC_CAP_OTHER_THREADS
    variable_frame_size = lib.AV_CODEC_CAP_VARIABLE_FRAME_SIZE
    avoid_probing = lib.AV_CODEC_CAP_AVOID_PROBING
    hardware = lib.AV_CODEC_CAP_HARDWARE
    hybrid = lib.AV_CODEC_CAP_HYBRID
    encoder_reordered_opaque = 1 << 20
    encoder_flush = 1 << 21
    encoder_recon_frame = 1 << 22

class HWDeviceType(IntEnum):
    NONE = lib.AV_HWDEVICE_TYPE_NONE
    VDPAU = lib.AV_HWDEVICE_TYPE_VDPAU
    CUDA = lib.AV_HWDEVICE_TYPE_CUDA
    VAAPI = lib.AV_HWDEVICE_TYPE_VAAPI
    DXVA2 = lib.AV_HWDEVICE_TYPE_DXVA2
    QSV = lib.AV_HWDEVICE_TYPE_QSV
    VIDEOTOOLBOX = lib.AV_HWDEVICE_TYPE_VIDEOTOOLBOX
    D3D11VA = lib.AV_HWDEVICE_TYPE_D3D11VA
    DRM = lib.AV_HWDEVICE_TYPE_DRM
    OPENCL = lib.AV_HWDEVICE_TYPE_OPENCL
    MEDIACODEC = lib.AV_HWDEVICE_TYPE_MEDIACODEC
    VULKAN = lib.AV_HWDEVICE_TYPE_VULKAN
    D3D12VA = lib.AV_HWDEVICE_TYPE_D3D12VA

class HWConfigMethod(IntEnum):
    NONE = 0
    HW_DEVICE_CTX = lib.AV_CODEC_HW_CONFIG_METHOD_HW_DEVICE_CTX  # This is the only one we support.
    HW_FRAME_CTX = lib.AV_CODEC_HW_CONFIG_METHOD_HW_FRAMES_CTX
    INTERNAL = lib.AV_CODEC_HW_CONFIG_METHOD_INTERNAL
    AD_HOC = lib.AV_CODEC_HW_CONFIG_METHOD_AD_HOC


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
            f'device_type={lib.av_hwdevice_get_type_name(self.device_type)} '
            f'format={self.format.name if self.format else None} '
            f'is_supported={self.is_supported} '
            f'at 0x{<int>self.ptr:x}>'
        )

    @property
    def device_type(self):
        return HWDeviceType(self.ptr.device_type)

    @property
    def format(self):
        return get_video_format(self.ptr.pix_fmt, 0, 0)

    @property
    def methods(self):
        return HWConfigMethod(self.ptr.methods)

    @property
    def is_supported(self):
        return bool(self.ptr.methods & lib.AV_CODEC_HW_CONFIG_METHOD_HW_DEVICE_CTX)

hwdevices_available = []

cdef lib.AVHWDeviceType x = lib.AV_HWDEVICE_TYPE_NONE
while True:
    x = lib.av_hwdevice_iterate_types(x)
    if x == lib.AV_HWDEVICE_TYPE_NONE:
        break
    hwdevices_available.append(lib.av_hwdevice_get_type_name(HWDeviceType(x)))

def dump_hwdevices():
    print('Hardware device types:')
    for x in hwdevices_available:
        print('   ', x)

cdef class HWAccel(object):
    def __init__(self, device_type: str | HWDeviceType, device: str | None = None,
                 allow_software_fallback: bool = True, options=None, **kwargs):
        if isinstance(device_type, HWDeviceType):
            self._device_type = device_type
        elif isinstance(device_type, str):
            self._device_type = int(lib.av_hwdevice_find_type_by_name(device_type))
        else:
            raise ValueError('Unknown type for device_type')
        self._device = device
        self.allow_software_fallback = allow_software_fallback

        if options and kwargs:
            raise ValueError("accepts only one of options arg or kwargs")
        self.options = dict(options or kwargs)

    def create(self, Codec codec):
        return HWAccelContext(
            device_type=HWDeviceType(self._device_type),
            device=self._device,
            options=self.options,
            codec=codec,
            allow_software_fallback=self.allow_software_fallback)

cdef class HWAccelContext(HWAccel):
    def __init__(self, device_type, device, options, codec, allow_software_fallback, **kwargs):
        super().__init__(device_type, device, options, **kwargs)
        if not codec:
            raise ValueError("codec is required")
        self.codec = codec
        cdef HWConfig config
        for config in codec.hardware_configs:
            if not (config.ptr.methods & lib.AV_CODEC_HW_CONFIG_METHOD_HW_DEVICE_CTX):
                continue
            if self._device_type and config.device_type != self._device_type:
                continue
            break
        else:
            raise NotImplementedError(f"no supported hardware config for {codec}")
        self.config = config
        cdef char *c_device = NULL
        if self._device:
            device_bytes = self._device.encode()
            c_device = device_bytes
        cdef _Dictionary c_options = Dictionary(self.options)
        err_check(lib.av_hwdevice_ctx_create(&self.ptr, config.ptr.device_type, c_device, c_options.ptr, 0))

    def __dealloc__(self):
        if self.ptr:
            lib.av_buffer_unref(&self.ptr)
    def create(self, *args, **kwargs):
        raise ValueError("cannot call HWAccelContext.create")
