
#include "libavcodec/avcodec.h"


const AVCodec* pyav_codec_iterate(const void **handle) {

#if LIBAVCODEC_VERSION_INT >= AV_VERSION_INT(58, 10, 100)
    return av_codec_iterate(handle);

#else
    const AVCodec *ptr;
    ptr = av_codec_next(*handle);
    *handle = ptr;
    return ptr;

#endif
}
