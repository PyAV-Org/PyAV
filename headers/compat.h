// This header serves to smooth out the differences in FFmpeg and LibAV.

// #include "libswresample/version.h"
// #include "libavresample/version.h"

#ifdef LIBSWRESAMPLE_VERSION_MAJOR
    #define PYAV_USING_FFMPEG
#endif
#ifdef LIBAVRESAMPLE_VERSION_MAJOR
    #define PYAV_USING_LIBAV
#endif


#ifdef PYAV_USING_LIBAV
    
    // Basic accessors.
    #define av_frame_get_best_effort_timestamp(frame_p) (frame_p->best_effort_timestamp)

    // Ignore this function.
    #define avformat_close_input(context_pp)

#endif

