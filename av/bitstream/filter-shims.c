
#include "libavcodec/avcodec.h"


const AVBitStreamFilter* pyav_filter_iterate(void **opaque) {

#if LIBAVCODEC_VERSION_INT >= AV_VERSION_INT(58, 10, 100)
    return av_bsf_iterate(opaque);

#else
    return av_bsf_next(opaque);

#endif
}
