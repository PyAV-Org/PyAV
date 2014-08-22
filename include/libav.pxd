
# This file is built by setup.py and contains macros telling us which libraries
# and functions we have (of those which are different between FFMpeg and LibAV).
cdef extern from "pyav/config.h" nogil:
    pass

include "libavutil/avutil.pxd"
include "libavutil/channel_layout.pxd"
include "libavutil/dict.pxd"
include "libavutil/samplefmt.pxd"

include "libavcodec/avcodec.pxd"
include "libavdevice/avdevice.pxd"
include "libavformat/avformat.pxd"
include "libswresample/swresample.pxd"
include "libswscale/swscale.pxd"
