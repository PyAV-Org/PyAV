from enum import IntEnum
from typing import Sequence

from av.codec.codec import Codec

class HWDeviceType(IntEnum):
    NONE = int
    VDPAU = int
    CUDA = int
    VAAPI = int
    DXVA2 = int
    QSV = int
    VIDEOTOOLBOX = int
    D3D11VA = int
    DRM = int
    OPENCL = int
    MEDIACODEC = int
    VULKAN = int
    D3D12VA = int

class HWConfig(object):
    def __init__(self, sentinel): ...
    def __repr__(self): ...
    @property
    def device_type(self): ...
    @property
    def format(self): ...
    @property
    def methods(self): ...
    @property
    def is_supported(self): ...

class HWAccel:
    def __init__(
        self,
        device_type: str | HWDeviceType,
        device: str | None = None,
        allow_software_fallback: bool = True,
        options=None,
        **kwargs
    ): ...
    def create(self, codec: Codec): ...

hwdevices_available: Sequence[str]

def dump_hwdevices() -> None: ...
