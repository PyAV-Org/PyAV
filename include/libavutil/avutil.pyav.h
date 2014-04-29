#include "libavutil/avutil.h"

#ifndef PYAV_HAVE_AV_CALLOC

#include "libavutil/mem.h"

void *av_calloc(size_t nmemb, size_t size)
{
    if (size <= 0 || nmemb >= INT_MAX / size)
        return NULL;
    return av_mallocz(nmemb * size);
}

#endif
