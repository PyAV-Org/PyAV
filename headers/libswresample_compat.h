// This header serves to smooth out the differences in FFmpeg and LibAV.

#ifndef USE_AVRESAMPLE

#include <libswresample/swresample.h>

//swr does not have the equivalent so this does nothing
void swr_close(SwrContext *ctx)
{
    
};

#else

//wrap libavresample so it looks the same as libswresample
#include <libavresample/avresample.h>

#define SwrContext AVAudioResampleContext
#define swr_init(ctx) avresample_open(ctx)
#define swr_close(ctx) avresample_close(ctx)
#define swr_free(ctx) avresample_free(ctx)
#define swr_alloc() avresample_alloc_context()
#define swr_get_delay(ctx, ...) avresample_get_delay(ctx)
#define swr_convert(ctx, out, out_count, in, in_count) avresample_convert(ctx, out, 0, out_count, in, 0, in_count)

#endif