from enum import IntEnum
from typing import Any, cast

import numpy as np

class VideoEncParamsType(IntEnum):
    NONE = cast(int, ...)
    VP9 = cast(int, ...)
    H264 = cast(int, ...)
    MPEG2 = cast(int, ...)

class VideoEncParams:
    nb_blocks: int
    blocks_offset: int
    block_size: int
    codec_type: VideoEncParamsType
    qp: int
    delta_qp: int
    def block_params(self, idx: int) -> VideoBlockParams: ...
    def qp_map(self) -> np.ndarray[Any, Any]: ...

class VideoBlockParams:
    src_x: int
    src_y: int
    w: int
    h: int
    delta_qp: int
