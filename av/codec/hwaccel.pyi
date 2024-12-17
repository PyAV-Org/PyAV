from enum import IntEnum

from av.codec.codec import Codec
from av.video.format import VideoFormat

class HWDeviceType(IntEnum):
    none: int
    vdpau: int
    cuda: int
    vaapi: int
    dxva2: int
    qsv: int
    videotoolbox: int
    d3d11va: int
    drm: int
    opencl: int
    mediacodec: int
    vulkan: int
    d3d12va: int

class HWConfigMethod(IntEnum):
    none: int
    hw_device_ctx: int
    hw_frame_ctx: int
    internal: int
    ad_hoc: int

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
    ) -> None: ...
    def create(self, codec: Codec) -> HWAccel: ...

def hwdevices_available() -> list[str]: ...
