#include "libavcodec/avcodec.h"

#ifndef HAVE_AV_FRAME_GET_BEST_EFFORT_TIMESTAMP

int64_t av_frame_get_best_effort_timestamp(const AVFrame *frame) 
{
//this is wrong but a quick fix
return frame->pkt_pts;
}

#endif
