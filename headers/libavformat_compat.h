// This header serves to smooth out the differences in FFmpeg and LibAV.

#include <libavformat/avformat.h>

#ifndef HAVE_AVFORMAT_CLOSE_INPUT
    #define avformat_close_input(context_pp) av_close_input_file(*context_pp)
#endif

