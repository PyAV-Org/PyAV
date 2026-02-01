from enum import IntEnum

import cython
from cython.cimports import libav as lib
from cython.cimports.av.sidedata.sidedata import SideData
from cython.cimports.libc.stdint import uint8_t


class VideoEncParamsType(IntEnum):
    NONE = lib.AV_VIDEO_ENC_PARAMS_NONE
    VP9 = lib.AV_VIDEO_ENC_PARAMS_VP9
    H264 = lib.AV_VIDEO_ENC_PARAMS_H264
    MPEG2 = lib.AV_VIDEO_ENC_PARAMS_MPEG2


@cython.cclass
class VideoEncParams(SideData):
    def __repr__(self):
        return f"<av.sidedata.VideoEncParams, nb_blocks={self.nb_blocks}, codec_type={self.codec_type}, qp={self.qp}>"

    @property
    def nb_blocks(self):
        """
        Number of blocks in the array
        May be 0, in which case no per-block information is present. In this case
        the values of blocks_offset / block_size are unspecified and should not
        be accessed.
        """
        return cython.cast(
            cython.pointer[lib.AVVideoEncParams], self.ptr.data
        ).nb_blocks

    @property
    def blocks_offset(self):
        """
        Offset in bytes from the beginning of this structure at which the array of blocks starts.
        """
        return cython.cast(
            cython.pointer[lib.AVVideoEncParams], self.ptr.data
        ).blocks_offset

    @property
    def block_size(self):
        """
        Size of each block in bytes. May not match sizeof(AVVideoBlockParams).
        """
        return cython.cast(
            cython.pointer[lib.AVVideoEncParams], self.ptr.data
        ).block_size

    @property
    def codec_type(self):
        """
        Type of the parameters (the codec they are used with).
        """
        t: lib.AVVideoEncParamsType = cython.cast(
            cython.pointer[lib.AVVideoEncParams], self.ptr.data
        ).type
        return VideoEncParamsType(cython.cast(cython.int, t))

    @property
    def qp(self):
        """
        Base quantisation parameter for the frame. The final quantiser for a
        given block in a given plane is obtained from this value, possibly
        combined with `delta_qp` and the per-block delta in a manner
        documented for each type.
        """
        return cython.cast(cython.pointer[lib.AVVideoEncParams], self.ptr.data).qp

    @property
    def delta_qp(self):
        """
        Quantisation parameter offset from the base (per-frame) qp for a given
        plane (first index) and AC/DC coefficients (second index).
        """
        p: cython.pointer[lib.AVVideoEncParams] = cython.cast(
            cython.pointer[lib.AVVideoEncParams], self.ptr.data
        )
        return [[p.delta_qp[i][j] for j in range(2)] for i in range(4)]

    def block_params(self, idx):
        """
        Get the encoding parameters for a given block
        """
        # Validate given index
        if idx < 0 or idx >= self.nb_blocks:
            raise ValueError("Expected idx in range [0, nb_blocks)")

        return VideoBlockParams(self, idx)

    def qp_map(self):
        """
        Convenience method that creates a 2-D map with the quantization parameters per macroblock.
        Only for MPEG2 and H264 encoded videos.
        """
        import numpy as np

        mb_h: cython.int = (self.frame.ptr.height + 15) // 16
        mb_w: cython.int = (self.frame.ptr.width + 15) // 16
        nb_mb: cython.int = mb_h * mb_w
        block_idx, x, y = cython.declare(cython.int)
        block: VideoBlockParams

        if self.nb_blocks != nb_mb:
            raise RuntimeError(
                "Expected frame size to match number of blocks in side data"
            )

        type: lib.AVVideoEncParamsType = cython.cast(
            cython.pointer[lib.AVVideoEncParams], self.ptr.data
        ).type
        if (
            type != lib.AVVideoEncParamsType.AV_VIDEO_ENC_PARAMS_MPEG2
            and type != lib.AVVideoEncParamsType.AV_VIDEO_ENC_PARAMS_H264
        ):
            raise ValueError("Expected MPEG2 or H264")

        # Create a 2-D map with the number of macroblocks
        map = np.empty((mb_h, mb_w), dtype=np.int32)

        # Fill map with quantization parameter per macroblock
        for block_idx in range(nb_mb):
            block = VideoBlockParams(self, block_idx)
            y = block.src_y // 16
            x = block.src_x // 16
            map[y, x] = self.qp + block.delta_qp

        return map


@cython.cclass
class VideoBlockParams:
    def __init__(self, video_enc_params: VideoEncParams, idx: cython.int) -> None:
        base: cython.pointer[uint8_t] = cython.cast(
            cython.pointer[uint8_t], video_enc_params.ptr.data
        )
        offset: cython.Py_ssize_t = (
            video_enc_params.blocks_offset + idx * video_enc_params.block_size
        )
        self.ptr = cython.cast(cython.pointer[lib.AVVideoBlockParams], base + offset)

    def __repr__(self):
        return f"<av.sidedata.VideoBlockParams, src=({self.src_x}, {self.src_y}), size={self.w}x{self.h}, delta_qp={self.delta_qp}>"

    @property
    def src_x(self):
        """
        Horizontal distance in luma pixels from the top-left corner of the visible frame
        to the top-left corner of the block.
        Can be negative if top/right padding is present on the coded frame.
        """
        return self.ptr.src_x

    @property
    def src_y(self):
        """
        Vertical distance in luma pixels from the top-left corner of the visible frame
        to the top-left corner of the block.
        Can be negative if top/right padding is present on the coded frame.
        """
        return self.ptr.src_y

    @property
    def w(self):
        """
        Width of the block in luma pixels
        """
        return self.ptr.w

    @property
    def h(self):
        """
        Height of the block in luma pixels
        """
        return self.ptr.h

    @property
    def delta_qp(self):
        """
        Difference between this block's final quantization parameter and the
        corresponding per-frame value.
        """
        return self.ptr.delta_qp
