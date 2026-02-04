cimport libav as lib

cdef extern from "libavutil/hwcontext.h" nogil:
    ctypedef struct AVHWFramesContext:
        const void *av_class
        lib.AVBufferRef *device_ref
        void *device_ctx
        void *hwctx
        lib.AVPixelFormat format
        lib.AVPixelFormat sw_format
        int width
        int height

    lib.AVBufferRef *av_hwframe_ctx_alloc(lib.AVBufferRef *device_ref)
    int av_hwframe_ctx_init(lib.AVBufferRef *ref)
