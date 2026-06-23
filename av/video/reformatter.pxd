cimport libav as lib

from av.video.frame cimport VideoFrame


cdef extern from "libswscale/swscale.h" nogil:
    cdef struct SwsContext:
        unsigned flags
        int threads

    cdef int SWS_FAST_BILINEAR
    cdef int SWS_BILINEAR
    cdef int SWS_BICUBIC
    cdef int SWS_X
    cdef int SWS_POINT
    cdef int SWS_AREA
    cdef int SWS_BICUBLIN
    cdef int SWS_GAUSS
    cdef int SWS_SINC
    cdef int SWS_LANCZOS
    cdef int SWS_SPLINE
    cdef int SWS_PRINT_INFO
    cdef int SWS_FULL_CHR_H_INT
    cdef int SWS_FULL_CHR_H_INP
    cdef int SWS_DIRECT_BGR
    cdef int SWS_ACCURATE_RND
    cdef int SWS_BITEXACT
    cdef int SWS_ERROR_DIFFUSION
    cdef int SWS_CS_ITU709
    cdef int SWS_CS_FCC
    cdef int SWS_CS_ITU601
    cdef int SWS_CS_ITU624
    cdef int SWS_CS_SMPTE170M
    cdef int SWS_CS_SMPTE240M
    cdef int SWS_CS_DEFAULT
    cdef int SWS_CS_BT2020

    cdef SwsContext *sws_alloc_context()
    cdef void sws_free_context(SwsContext **ctx)
    cdef int sws_is_noop(const lib.AVFrame *dst, const lib.AVFrame *src)
    cdef int sws_scale_frame(SwsContext *c, lib.AVFrame *dst, const lib.AVFrame *src)

cdef class VideoReformatter:
    cdef SwsContext *ptr
    cdef _reformat(self, VideoFrame frame, int width, int height,
                   lib.AVPixelFormat format, int src_colorspace,
                   int dst_colorspace, int interpolation,
                   int src_color_range, int dst_color_range,
                   int dst_color_trc, int dst_color_primaries,
                   int threads)
