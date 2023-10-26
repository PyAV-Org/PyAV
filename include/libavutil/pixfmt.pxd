cdef extern from "libavutil/pixfmt.h" nogil:

    cdef enum AVPixelFormat:
        AV_PIX_FMT_NONE
        AV_PIX_FMT_YUV420P
        AV_PIX_FMT_RGB24
        PIX_FMT_RGB24
        PIX_FMT_RGBA
