#include "libavcodec/avcodec.h"

#ifndef PYAV_HAVE_AV_FRAME_GET_BEST_EFFORT_TIMESTAMP

    int64_t av_frame_get_best_effort_timestamp(const AVFrame *frame) 
    {
        // TODO: do this right.
        return frame->pkt_pts;
    }

#endif


#ifdef PYAV_HAVE_FFMPEG

    #define AVPixelFormat PixelFormat
    #define AV_PIX_FMT_YUV420P PIX_FMT_YUV420P

#endif
