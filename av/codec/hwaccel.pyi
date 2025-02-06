from enum import IntEnum
from typing import cast

from av.codec.codec import Codec
from av.video.format import VideoFormat

class HWDeviceType(IntEnum):
    none = cast(int, ...)
    vdpau = cast(int, ...)
    cuda = cast(int, ...)
    vaapi = cast(int, ...)
    dxva2 = cast(int, ...)
    qsv = cast(int, ...)
    videotoolbox = cast(int, ...)
    d3d11va = cast(int, ...)
    drm = cast(int, ...)
    opencl = cast(int, ...)
    mediacodec = cast(int, ...)
    vulkan = cast(int, ...)
    d3d12va = cast(int, ...)

class HWConfigMethod(IntEnum):
    none = cast(int, ...)
    hw_device_ctx = cast(int, ...)
    hw_frame_ctx = cast(int, ...)
    internal = cast(int, ...)
    ad_hoc = cast(int, ...)

class HWConfig:
    @property
    def device_type(self) -> HWDeviceType: ...
    @property
    def format(self) -> VideoFormat: ...
    @property
    def methods(self) -> HWConfigMethod: ...
    @property
    def is_supported(self) -> bool: ...

class HWAccel:
    def __init__(
        self,
        device_type: str | HWDeviceType,
        device: str | None = None,
        allow_software_fallback: bool = False,
        options: dict[str, object] | None = None,
        flags: int | None = None,
    ) -> None: ...
    def create(self, codec: Codec) -> HWAccel: ...

def hwdevices_available() -> list[str]: ...
