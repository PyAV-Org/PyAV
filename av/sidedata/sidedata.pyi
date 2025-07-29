from collections.abc import Mapping
from enum import Enum
from typing import ClassVar, Iterator, Sequence, cast, overload

from av.buffer import Buffer
from av.frame import Frame

class Type(Enum):
    PANSCAN = cast(ClassVar[Type], ...)
    A53_CC = cast(ClassVar[Type], ...)
    STEREO3D = cast(ClassVar[Type], ...)
    MATRIXENCODING = cast(ClassVar[Type], ...)
    DOWNMIX_INFO = cast(ClassVar[Type], ...)
    REPLAYGAIN = cast(ClassVar[Type], ...)
    DISPLAYMATRIX = cast(ClassVar[Type], ...)
    AFD = cast(ClassVar[Type], ...)
    MOTION_VECTORS = cast(ClassVar[Type], ...)
    SKIP_SAMPLES = cast(ClassVar[Type], ...)
    AUDIO_SERVICE_TYPE = cast(ClassVar[Type], ...)
    MASTERING_DISPLAY_METADATA = cast(ClassVar[Type], ...)
    GOP_TIMECODE = cast(ClassVar[Type], ...)
    SPHERICAL = cast(ClassVar[Type], ...)
    CONTENT_LIGHT_LEVEL = cast(ClassVar[Type], ...)
    ICC_PROFILE = cast(ClassVar[Type], ...)
    S12M_TIMECODE = cast(ClassVar[Type], ...)
    DYNAMIC_HDR_PLUS = cast(ClassVar[Type], ...)
    REGIONS_OF_INTEREST = cast(ClassVar[Type], ...)
    VIDEO_ENC_PARAMS = cast(ClassVar[Type], ...)
    SEI_UNREGISTERED = cast(ClassVar[Type], ...)
    FILM_GRAIN_PARAMS = cast(ClassVar[Type], ...)
    DETECTION_BBOXES = cast(ClassVar[Type], ...)
    DOVI_RPU_BUFFER = cast(ClassVar[Type], ...)
    DOVI_METADATA = cast(ClassVar[Type], ...)
    DYNAMIC_HDR_VIVID = cast(ClassVar[Type], ...)
    AMBIENT_VIEWING_ENVIRONMENT = cast(ClassVar[Type], ...)
    VIDEO_HINT = cast(ClassVar[Type], ...)

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
