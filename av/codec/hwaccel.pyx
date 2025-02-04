import weakref
from enum import IntEnum

cimport libav as lib

from av.codec.codec cimport Codec
from av.dictionary cimport _Dictionary
from av.error cimport err_check
from av.video.format cimport get_video_format

from av.dictionary import Dictionary


class HWDeviceType(IntEnum):
    none = lib.AV_HWDEVICE_TYPE_NONE
    vdpau = lib.AV_HWDEVICE_TYPE_VDPAU
    cuda = lib.AV_HWDEVICE_TYPE_CUDA
    vaapi = lib.AV_HWDEVICE_TYPE_VAAPI
    dxva2 = lib.AV_HWDEVICE_TYPE_DXVA2
    qsv = lib.AV_HWDEVICE_TYPE_QSV
    videotoolbox = lib.AV_HWDEVICE_TYPE_VIDEOTOOLBOX
    d3d11va = lib.AV_HWDEVICE_TYPE_D3D11VA
    drm = lib.AV_HWDEVICE_TYPE_DRM
    opencl = lib.AV_HWDEVICE_TYPE_OPENCL
    mediacodec = lib.AV_HWDEVICE_TYPE_MEDIACODEC
    vulkan = lib.AV_HWDEVICE_TYPE_VULKAN
    d3d12va = lib.AV_HWDEVICE_TYPE_D3D12VA

class HWConfigMethod(IntEnum):
    none = 0
    hw_device_ctx = lib.AV_CODEC_HW_CONFIG_METHOD_HW_DEVICE_CTX  # This is the only one we support.
    hw_frame_ctx = lib.AV_CODEC_HW_CONFIG_METHOD_HW_FRAMES_CTX
    internal = lib.AV_CODEC_HW_CONFIG_METHOD_INTERNAL
    ad_hoc = lib.AV_CODEC_HW_CONFIG_METHOD_AD_HOC


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


cdef class HWConfig:
    def __init__(self, sentinel):
        if sentinel is not _cinit_sentinel:
            raise RuntimeError("Cannot instantiate CodecContext")

    cdef void _init(self, lib.AVCodecHWConfig *ptr):
        self.ptr = ptr

    def __repr__(self):
        return (
            f"<av.{self.__class__.__name__} "
            f"device_type={lib.av_hwdevice_get_type_name(self.device_type)} "
            f"format={self.format.name if self.format else None} "
            f"is_supported={self.is_supported} at 0x{<int>self.ptr:x}>"
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


cpdef hwdevices_available():
    result = []

    cdef lib.AVHWDeviceType x = lib.AV_HWDEVICE_TYPE_NONE
    while True:
        x = lib.av_hwdevice_iterate_types(x)
        if x == lib.AV_HWDEVICE_TYPE_NONE:
            break
        result.append(lib.av_hwdevice_get_type_name(HWDeviceType(x)))

    return result


cdef class HWAccel:
    def __init__(self, device_type, device=None, allow_software_fallback=True, options=None, flags=None):
        if isinstance(device_type, HWDeviceType):
            self._device_type = device_type
        elif isinstance(device_type, str):
            self._device_type = int(lib.av_hwdevice_find_type_by_name(device_type))
        elif isinstance(device_type, int):
            self._device_type = device_type
        else:
            raise ValueError("Unknown type for device_type")

        self._device = device
        self.allow_software_fallback = allow_software_fallback
        self.options = {} if not options else dict(options)
        self.flags = 0 if not flags else flags
        self.ptr = NULL
        self.config = None

    def _initialize_hw_context(self, Codec codec not None):
        cdef HWConfig config
        for config in codec.hardware_configs:
            if not (config.ptr.methods & lib.AV_CODEC_HW_CONFIG_METHOD_HW_DEVICE_CTX):
                continue
            if self._device_type and config.device_type != self._device_type:
                continue
            break
        else:
            raise NotImplementedError(f"No supported hardware config for {codec}")

        self.config = config

        cdef char *c_device = NULL
        if self._device:
            device_bytes = self._device.encode()
            c_device = device_bytes
        cdef _Dictionary c_options = Dictionary(self.options)

        err_check(
            lib.av_hwdevice_ctx_create(
                &self.ptr, config.ptr.device_type, c_device, c_options.ptr, self.flags
            )
        )

    def create(self, Codec codec not None):
        """Create a new hardware accelerator context with the given codec"""
        if self.ptr:
            raise RuntimeError("Hardware context already initialized")

        ret = HWAccel(
            device_type=self._device_type,
            device=self._device,
            allow_software_fallback=self.allow_software_fallback,
            options=self.options
        )
        ret._initialize_hw_context(codec)
        return ret

    def __dealloc__(self):
        if self.ptr:
            lib.av_buffer_unref(&self.ptr)
