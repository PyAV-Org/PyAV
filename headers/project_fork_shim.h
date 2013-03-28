// This header serves to smooth out the differences in FFmpeg and LibAV.

#ifndef HAVE_AVFORMAT_CLOSE_INPUT
    // It is wrong to just ignore this.
    #define avformat_close_input(context_pp)
#endif

