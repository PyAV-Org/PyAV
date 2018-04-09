#include "libavutil/avutil.h"

#if !PYAV_HAVE_AV_CALLOC

#include "libavutil/mem.h"

void *av_calloc(size_t nmemb, size_t size)
{
    if (size <= 0 || nmemb >= INT_MAX / size)
        return NULL;
    return av_mallocz(nmemb * size);
}
#endif


#if !PYAV_HAVE_AV_OPT_TYPE_BOOL
#define AV_OPT_TYPE_BOOL MKBETAG('B','O','O','L')
#endif

