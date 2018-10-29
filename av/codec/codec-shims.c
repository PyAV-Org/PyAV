
#include "libavcodec/avcodec.h"


const AVCodec* pyav_codec_iterate(void **opaque) {

#if LIBAVCODEC_VERSION_INT >= AV_VERSION_INT(58, 10, 100)
    return av_codec_iterate(opaque);

#else
    const AVCodec *ptr;
    ptr = av_codec_next((const AVCodec*)*opaque);
    *opaque = (void*)ptr;
    return ptr;

#endif
}
