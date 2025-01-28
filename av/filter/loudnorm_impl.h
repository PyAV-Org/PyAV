#ifndef AV_FILTER_LOUDNORM_H
#define AV_FILTER_LOUDNORM_H

#include <libavcodec/avcodec.h>

char* loudnorm_get_stats(
    AVFormatContext* fmt_ctx,
    int audio_stream_index,
    const char* loudnorm_args
);

#endif // AV_FILTER_LOUDNORM_H