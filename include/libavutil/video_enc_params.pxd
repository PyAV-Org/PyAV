from libc.stdint cimport uint32_t, int32_t
from libc.stddef cimport size_t


cdef extern from "libavutil/video_enc_params.h" nogil:
    cdef enum AVVideoEncParamsType:
        AV_VIDEO_ENC_PARAMS_NONE
        AV_VIDEO_ENC_PARAMS_VP9
        AV_VIDEO_ENC_PARAMS_H264
        AV_VIDEO_ENC_PARAMS_MPEG2

    cdef struct AVVideoEncParams:
        uint32_t                nb_blocks
        size_t                  blocks_offset
        size_t                  block_size
        AVVideoEncParamsType    type
        int32_t                 qp
        int32_t                 delta_qp[4][2]

    cdef struct AVVideoBlockParams:
        int32_t     src_x
        int32_t     src_y
        int32_t     w
        int32_t     h
        int32_t     delta_qp