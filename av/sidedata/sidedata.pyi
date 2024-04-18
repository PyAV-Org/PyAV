from collections.abc import Mapping
from typing import Iterator, Sequence, overload

from av.buffer import Buffer
from av.enum import EnumItem
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
    S12M_TIMECODE: int

class SideData(Buffer):
    type: Type
    DISPLAYMATRIX: int

class SideDataContainer(Mapping):
    frame: Frame
    def __len__(self) -> int: ...
    def __iter__(self) -> Iterator[SideData]: ...
    @overload
    def __getitem__(self, key: int) -> SideData: ...
    @overload
    def __getitem__(self, key: slice) -> Sequence[SideData]: ...
    @overload
    def __getitem__(self, key: int | slice) -> SideData | Sequence[SideData]: ...
