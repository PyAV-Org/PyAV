cimport libav as lib

from av.video.frame cimport VideoFrame


cdef class VideoReformatter:

    cdef lib.SwsContext *ptr

    cdef _reformat(self, VideoFrame frame, int width, int height,
                   lib.AVPixelFormat format, int src_colorspace,
                   int dst_colorspace, int interpolation,
                   int src_color_range, int dst_color_range)
