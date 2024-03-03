from collections.abc import Mapping

from av.enum import EnumItem
from av.buffer import Buffer
from av.frame import Frame

class Type(EnumItem):
    PANSCAN: int
    A53_CC: int
    STEREO3D: int
    MATRIXENCODING: int
    DOWNMIX_INFO: int
    REPLAYGAIN: int
    DISPLAYMATRIX: int
    AFD: int
    MOTION_VECTORS: int
    SKIP_SAMPLES: int
    AUDIO_SERVICE_TYPE: int
    MASTERING_DISPLAY_METADATA: int
    GOP_TIMECODE: int
    SPHERICAL: int
    CONTENT_LIGHT_LEVEL: int
    ICC_PROFILE: int
    SEI_UNREGISTERED: int

class SideData(Buffer):
    type: Type
    DISPLAYMATRIX: int

class _SideDataContainer:
    frame: Frame

class SideDataContainer(_SideDataContainer, Mapping[str, int]): ...
