cdef extern from *:
    """
    #ifndef CUDA_VERSION
    #define PYAV_CUDA_TYPES
    #define CUDA_VERSION 1
    typedef struct CUctx_st *CUcontext;
    typedef struct CUstream_st *CUstream;
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
