import weakref
from enum import IntEnum

import cython
import cython.cimports.libav as lib
from cython.cimports.av.codec.codec import Codec
from cython.cimports.av.dictionary import Dictionary
from cython.cimports.av.error import err_check
from cython.cimports.av.video.format import get_video_format


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
    amf = 13  # FFmpeg >=8
    ohcodec = 14
    # TODO: When ffmpeg major is changed, check this enum.


class HWConfigMethod(IntEnum):
    none = 0
    hw_device_ctx = (
        lib.AV_CODEC_HW_CONFIG_METHOD_HW_DEVICE_CTX
    )  # This is the only one we support.
    hw_frame_ctx = lib.AV_CODEC_HW_CONFIG_METHOD_HW_FRAMES_CTX
    internal = lib.AV_CODEC_HW_CONFIG_METHOD_INTERNAL
    ad_hoc = lib.AV_CODEC_HW_CONFIG_METHOD_AD_HOC


_cinit_sentinel = cython.declare(object, object())
_singletons = cython.declare(object, weakref.WeakValueDictionary())


@cython.cfunc
def wrap_hwconfig(ptr: cython.pointer[lib.AVCodecHWConfig]) -> HWConfig:
    try:
        return _singletons[cython.cast(cython.int, ptr)]
    except KeyError:
        pass
    config: HWConfig = HWConfig(_cinit_sentinel)
    config._init(ptr)
    _singletons[cython.cast(cython.int, ptr)] = config
    return config


@cython.cclass
class HWConfig:
    def __init__(self, sentinel):
        if sentinel is not _cinit_sentinel:
            raise RuntimeError("Cannot instantiate CodecContext")

    @cython.cfunc
    def _init(self, ptr: cython.pointer[lib.AVCodecHWConfig]) -> cython.void:
        self.ptr = ptr

    def __repr__(self):
        return (
            f"<av.{self.__class__.__name__} "
            f"device_type={lib.av_hwdevice_get_type_name(self.device_type)} "
            f"format={self.format.name if self.format else None} "
            f"is_supported={self.is_supported} at 0x{cython.cast(int, self.ptr):x}>"
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


@cython.ccall
def hwdevices_available():
    result: list = []
    x: lib.AVHWDeviceType = lib.AV_HWDEVICE_TYPE_NONE
    while True:
        x = lib.av_hwdevice_iterate_types(x)
        if x == lib.AV_HWDEVICE_TYPE_NONE:
            break
        result.append(lib.av_hwdevice_get_type_name(HWDeviceType(x)))
    return result


@cython.cclass
class HWAccel:
    def __init__(
        self,
        device_type,
        device=None,
        allow_software_fallback=True,
        options=None,
        flags=None,
        is_hw_owned=False,
    ):
        if isinstance(device_type, HWDeviceType):
            self._device_type = device_type
        elif isinstance(device_type, str):
            self._device_type = int(lib.av_hwdevice_find_type_by_name(device_type))
        elif isinstance(device_type, int):
            self._device_type = device_type
        else:
            raise ValueError("Unknown type for device_type")

        self.is_hw_owned = is_hw_owned
        self.device_id = 0
        if self._device_type == HWDeviceType.cuda and device:
            self.device_id = int(device)

        self._device = None if device is None else f"{device}"
        self.allow_software_fallback = allow_software_fallback

        self.options = {} if not options else dict(options)
        if self._device_type == HWDeviceType.cuda and self.is_hw_owned:
            self.options.setdefault("primary_ctx", "1")
        self.flags = 0 if not flags else flags
        self.ptr = cython.NULL
        self.config = None

    def _initialize_hw_context(self, codec: Codec):
        config: HWConfig
        for config in codec.hardware_configs:
            if not (config.ptr.methods & lib.AV_CODEC_HW_CONFIG_METHOD_HW_DEVICE_CTX):
                continue
            if self._device_type and config.device_type != self._device_type:
                continue
            break
        else:  # nobreak
            raise NotImplementedError(f"No supported hardware config for {codec}")

        self.config = config
        c_device: cython.p_char = cython.NULL
        if self._device:
            device_bytes = self._device.encode()
            c_device = device_bytes
        c_options: Dictionary = Dictionary(self.options)

        err_check(
            lib.av_hwdevice_ctx_create(
                cython.address(self.ptr),
                config.ptr.device_type,
                c_device,
                c_options.ptr,
                self.flags,
            )
        )

    def create(self, codec: Codec) -> HWAccel:
        """Create a new hardware accelerator context with the given codec"""
        if self.ptr:
            raise RuntimeError("Hardware context already initialized")

        ret = HWAccel(
            device_type=self._device_type,
            device=self._device,
            allow_software_fallback=self.allow_software_fallback,
            options=self.options,
        )
        ret._initialize_hw_context(codec)
        return ret

    def __dealloc__(self):
        if self.ptr:
            lib.av_buffer_unref(cython.address(self.ptr))
