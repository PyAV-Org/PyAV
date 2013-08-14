cdef extern from "libswscale/swscale.h":
    
    # See: http://ffmpeg.org/doxygen/trunk/structSwsContext.html
    cdef struct SwsContext:
        pass
    
    # See: http://ffmpeg.org/doxygen/trunk/structSwsFilter.html
    cdef struct SwsFilter:
        pass
    
    # Flags.
    cdef int SWS_BILINEAR
    cdef int SWS_BICUBIC
    
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
        
    