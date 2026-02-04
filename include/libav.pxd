include "libavutil/avutil.pxd"
include "libavcodec/avcodec.pxd"
include "libavcodec/bsf.pxd"
include "libavcodec/hwaccel.pxd"

include "libavdevice/avdevice.pxd"
include "libavformat/avformat.pxd"
include "libswresample/swresample.pxd"
include "libswscale/swscale.pxd"

include "libavfilter/avfilter.pxd"
include "libavfilter/avfiltergraph.pxd"
include "libavfilter/buffersink.pxd"
include "libavfilter/buffersrc.pxd"


cdef extern from "stdio.h" nogil:
    cdef int snprintf(char *output, int n, const char *format, ...)
    cdef int vsnprintf(char *output, int n, const char *format, va_list args)
