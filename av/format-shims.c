
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


const AVOutputFormat* pyav_muxer_iterate(const void **handle) {

#if LIBAVFORMAT_VERSION_INT >= AV_VERSION_INT(58, 9, 100)
    return av_muxer_iterate(handle);

#else
    const AVOutputFormat *ptr;
    ptr = av_oformat_next(*handle);
    *handle = ptr;
    return ptr;

#endif
}


const AVInputFormat* pyav_demuxer_iterate(const void **handle) {

#if LIBAVFORMAT_VERSION_INT >= AV_VERSION_INT(58, 9, 100)
    return av_demuxer_iterate(handle);

#else
    const AVInputFormat *ptr;
    ptr = av_iformat_next(*handle);
    *handle = ptr;
    return ptr;

#endif
}

