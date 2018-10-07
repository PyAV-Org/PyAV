
#include <libavformat/avformat.h>


AVOutputFormat* pyav_find_output_format(const char *name) {

    const AVOutputFormat *ptr = NULL;

#if LIBAVFORMAT_VERSION_INT >= AV_VERSION_INT(58, 9, 100)
    void *opaque = NULL;
    while ((ptr = av_muxer_iterate(&opaque))) {
        if (!strcmp(ptr->name, name))
            return (AVOutputFormat*)ptr;
    }

#else
    while ((ptr = av_oformat_next(ptr))) {
        if (!strcmp(ptr->name, name))
            return (AVOutputFormat*)ptr;
    }

#endif

    return NULL;

}


const AVOutputFormat* pyav_muxer_iterate(void **opaque) {

#if LIBAVFORMAT_VERSION_INT >= AV_VERSION_INT(58, 9, 100)
    return av_muxer_iterate(opaque);

#else
    const AVOutputFormat *ptr;
    ptr = av_oformat_next((const AVOutputFormat*)*opaque);
    *opaque = (void*)ptr;
    return ptr;

#endif
}


const AVInputFormat* pyav_demuxer_iterate(void **opaque) {

#if LIBAVFORMAT_VERSION_INT >= AV_VERSION_INT(58, 9, 100)
    return av_demuxer_iterate(opaque);

#else
    const AVInputFormat *ptr;
    ptr = av_iformat_next((const AVInputFormat*)*opaque);
    *opaque = (void*)ptr;
    return ptr;

#endif
}

