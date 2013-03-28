// This header serves to smooth out the differences in FFmpeg and LibAV.

#ifndef HAVE_AV_FRAME_GET_BEST_EFFORT_TIMESTAMP
    #define av_frame_get_best_effort_timestamp(frame_p) (frame_p->best_effort_timestamp)
#endif

#ifndef HAVE_AVFORMAT_CLOSE_INPUT
    // This is wrong.
    #define avformat_close_input(context_pp)
#endif

