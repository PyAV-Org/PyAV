cimport libav as lib

cdef class VideoReformatter(object):
    def __dealloc__(self):
        with nogil:
            lib.sws_freeContext(self.ptr)

SWS_FAST_BILINEAR = lib.SWS_FAST_BILINEAR
SWS_BILINEAR = lib.SWS_BILINEAR
SWS_BICUBIC = lib.SWS_BICUBIC
SWS_X = lib.SWS_X
SWS_POINT = lib.SWS_POINT
SWS_AREA = lib.SWS_AREA
SWS_BICUBLIN = lib.SWS_BICUBLIN
SWS_GAUSS = lib.SWS_GAUSS
SWS_SINC = lib.SWS_SINC
SWS_LANCZOS = lib.SWS_LANCZOS
SWS_SPLINE = lib.SWS_SPLINE

