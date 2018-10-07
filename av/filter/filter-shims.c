#include "libavfilter/avfilter.h"

const AVFilter* pyav_filter_iterate(void **opaque) {

#if LIBAVFILTER_VERSION_INT >= AV_VERSION_INT(7, 14, 100)
    return av_filter_iterate(opaque);

#else
    const AVFilter *ptr;
    ptr = avfilter_next((const AVFilter*)*opaque);
    *opaque = (void*)ptr;
    return ptr;

#endif
}
