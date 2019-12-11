
cdef extern from "libswscale/swscale.h" nogil:

    cdef int   swscale_version()
    cdef char* swscale_configuration()
    cdef char* swscale_license()

    # See: http://ffmpeg.org/doxygen/trunk/structSwsContext.html
    cdef struct SwsContext:
        pass

    # See: http://ffmpeg.org/doxygen/trunk/structSwsFilter.html
    cdef struct SwsFilter:
        pass

    # Flags.
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

    cdef int SWS_CS_ITU709
    cdef int SWS_CS_FCC
    cdef int SWS_CS_ITU601
    cdef int SWS_CS_ITU624
    cdef int SWS_CS_SMPTE170M
    cdef int SWS_CS_SMPTE240M
    cdef int SWS_CS_DEFAULT

    cdef SwsContext* sws_getContext(
        int src_width,
        int src_height,
        AVPixelFormat src_format,
        int dst_width,
        int dst_height,
        AVPixelFormat dst_format,
        int flags,
        SwsFilter *src_filter,
        SwsFilter *dst_filter,
        double *param,
    )

    cdef int sws_scale(
        SwsContext *ctx,
        unsigned char **src_slice,
        int *src_stride,
        int src_slice_y,
        int src_slice_h,
        unsigned char **dst_slice,
        int *dst_stride,
    )

    cdef void sws_freeContext(SwsContext *ctx)

    cdef SwsContext *sws_getCachedContext(
        SwsContext *context,
        int src_width,
        int src_height,
        AVPixelFormat src_format,
        int dst_width,
        int dst_height,
        AVPixelFormat dst_format,
        int flags,
        SwsFilter *src_filter,
        SwsFilter *dst_filter,
        double *param,
    )

    cdef int* sws_getCoefficients(int colorspace)

    cdef int sws_getColorspaceDetails(
        SwsContext *context,
        int **inv_table,
        int *srcRange,
        int **table,
        int *dstRange,
        int *brightness,
        int *contrast,
        int *saturation
    )

    cdef int sws_setColorspaceDetails(
        SwsContext *context,
        const int inv_table[4],
        int srcRange,
        const int table[4],
        int dstRange,
        int brightness,
        int contrast,
        int saturation
    )
