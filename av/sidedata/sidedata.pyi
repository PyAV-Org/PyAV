from collections.abc import Mapping
from enum import Enum
from typing import ClassVar, Iterator, Sequence, overload

from av.buffer import Buffer
from av.frame import Frame

class Type(Enum):
    PANSCAN: ClassVar[Type]
    A53_CC: ClassVar[Type]
    STEREO3D: ClassVar[Type]
    MATRIXENCODING: ClassVar[Type]
    DOWNMIX_INFO: ClassVar[Type]
    REPLAYGAIN: ClassVar[Type]
    DISPLAYMATRIX: ClassVar[Type]
    AFD: ClassVar[Type]
    MOTION_VECTORS: ClassVar[Type]
    SKIP_SAMPLES: ClassVar[Type]
    AUDIO_SERVICE_TYPE: ClassVar[Type]
    MASTERING_DISPLAY_METADATA: ClassVar[Type]
    GOP_TIMECODE: ClassVar[Type]
    SPHERICAL: ClassVar[Type]
    CONTENT_LIGHT_LEVEL: ClassVar[Type]
    ICC_PROFILE: ClassVar[Type]
    S12M_TIMECODE: ClassVar[Type]
    DYNAMIC_HDR_PLUS: ClassVar[Type]
    REGIONS_OF_INTEREST: ClassVar[Type]
    VIDEO_ENC_PARAMS: ClassVar[Type]
    SEI_UNREGISTERED: ClassVar[Type]
    FILM_GRAIN_PARAMS: ClassVar[Type]
    DETECTION_BBOXES: ClassVar[Type]
    DOVI_RPU_BUFFER: ClassVar[Type]
    DOVI_METADATA: ClassVar[Type]
    DYNAMIC_HDR_VIVID: ClassVar[Type]
    AMBIENT_VIEWING_ENVIRONMENT: ClassVar[Type]
    VIDEO_HINT: ClassVar[Type]

class SideData(Buffer):
    type: Type

class SideDataContainer(Mapping):
    frame: Frame
    def __len__(self) -> int: ...
    def __iter__(self) -> Iterator[SideData]: ...
    @overload
    def __getitem__(self, key: str | int | Type) -> SideData: ...
    @overload
    def __getitem__(self, key: slice) -> Sequence[SideData]: ...
    @overload
    def __getitem__(
        self, key: str | int | Type | slice
    ) -> SideData | Sequence[SideData]: ...
