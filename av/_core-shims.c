#include "libavcodec/avcodec.h"
#include "libavdevice/avdevice.h"
#include "libavfilter/avfilter.h"
#include "libavformat/avformat.h"

void pyav_register_all(void) {
    /*
     * Setup base library. While the docs and experience may lead us to believe we
     * don't need to call all of these (e.g. avcodec_register_all is usually
     * unnessesary), some users have found contexts in which they are required.
     */
#if LIBAVFORMAT_VERSION_INT < AV_VERSION_INT(58, 9, 100)
    av_register_all();
#endif
    avformat_network_init();
    avdevice_register_all();
#if LIBAVCODEC_VERSION_INT < AV_VERSION_INT(58, 10, 100)
    avcodec_register_all();
#endif
#if LIBAVFILTER_VERSION_INT < AV_VERSION_INT(7, 14, 100)
    avfilter_register_all();
#endif
}
