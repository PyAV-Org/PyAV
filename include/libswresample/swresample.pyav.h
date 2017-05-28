// This header serves to smooth out the differences in FFmpeg and LibAV.

#if PYAV_HAVE_LIBSWRESAMPLE

    #include <libswresample/swresample.h>

    // swr does not have the equivalent so this does nothing
    void swr_close(SwrContext *ctx) {};

#else

    #include <libavresample/avresample.h>

    #define SwrContext AVAudioResampleContext
    #define swr_init(ctx) avresample_open(ctx)
    #define swr_close(ctx) avresample_close(ctx)
    #define swr_free(ctx) avresample_free(ctx)
    #define swr_alloc() avresample_alloc_context()
    #define swr_get_delay(ctx, ...) avresample_get_delay(ctx)
    #define swr_convert(ctx, out, out_count, in, in_count) \
       avresample_convert(ctx, out, 0, out_count, (uint8_t **)in, 0, in_count)

#endif



#if !PYAV_HAVE_LIBAVRESAMPLE
    int avresample_version() { return -1; }
    const char* avresample_configuration() { return ""; }
    const char* avresample_license() { return ""; }
#endif

#if !PYAV_HAVE_LIBSWRESAMPLE
    int swresample_version() { return -1; }
    const char* swresample_configuration() { return ""; }
    const char* swresample_license() { return ""; }
#endif
