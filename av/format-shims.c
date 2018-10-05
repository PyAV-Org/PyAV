
#include <string.h>
#include <libavformat/avformat.h>

AVOutputFormat* pyav_find_output_format(const char *name)
{
    const AVOutputFormat *optr = NULL;

#if LIBAVFORMAT_VERSION_INT >= AV_VERSION_INT(58, 9, 100)
    void *opaque = NULL;
    while ((optr = av_muxer_iterate(&opaque))) {
        if (!strcmp(optr->name, name))
            return (AVOutputFormat*)optr;
    }
#else
    while ((optr = av_oformat_next(optr))) {
        if (!strcmp(optr->name, name))
            return (AVOutputFormat*)optr;
    }
#endif

    return NULL;
}
