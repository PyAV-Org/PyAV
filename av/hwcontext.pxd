cimport libav as lib

cdef extern from "libavutil/hwcontext.h":
    ctypedef struct AVHWFramesContext:
        const void *av_class
        lib.AVBufferRef *device_ref
        void *device_ctx
        void *hwctx
        lib.AVPixelFormat format
        lib.AVPixelFormat sw_format
        int width
        int height
