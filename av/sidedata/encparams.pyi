from enum import IntEnum
from typing import Self, final

import numpy as np

from .sidedata import SideData

class VideoEncParamsType(IntEnum):
    NONE = ...
    VP9 = ...
    H264 = ...
    MPEG2 = ...

@final
class VideoEncParams(SideData):
    nb_blocks: int
    blocks_offset: int
    block_size: int
    codec_type: VideoEncParamsType
    qp: int
    delta_qp: int
    def block_params(self, idx: int) -> VideoBlockParams: ...
    def qp_map(self) -> np.ndarray[tuple[int, int], np.dtype[np.int32]]: ...

@final
class VideoBlockParams:
    src_x: int
    src_y: int
    w: int
    h: int
    delta_qp: int
    def __new__(cls, video_enc_params: VideoEncParams, idx: int, /) -> Self: ...
