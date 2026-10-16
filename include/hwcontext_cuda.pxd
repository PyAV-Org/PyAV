cdef extern from *:
    """
    #ifndef CUDA_VERSION
    #include <stddef.h>
    #define PYAV_CUDA_TYPES
    #define CUDA_VERSION 1
    typedef struct CUctx_st *CUcontext;
    typedef struct CUstream_st *CUstream;
    typedef struct CUarray_st *CUarray;
    typedef enum CUarray_format_enum {
        CU_AD_FORMAT_UNSIGNED_INT8 = 0x01
    } CUarray_format;
    typedef struct CUDA_ARRAY3D_DESCRIPTOR_st {
        size_t Width, Height, Depth;
        CUarray_format Format;
        unsigned int NumChannels, Flags;
    } CUDA_ARRAY3D_DESCRIPTOR;
    #endif
    #include <libavutil/hwcontext_cuda.h>
    #ifdef PYAV_CUDA_TYPES
    #undef CUDA_VERSION
    #undef PYAV_CUDA_TYPES
    #endif
    """
    ctypedef void *CUcontext
    ctypedef void *CUstream
    ctypedef struct AVCUDADeviceContext:
        CUcontext cuda_ctx
        CUstream stream
