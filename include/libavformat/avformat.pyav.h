// This header serves to smooth out the differences in FFmpeg versions.

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

PyObject* pyav_get_available_formats(void)
{
    const AVInputFormat *iptr = NULL;
    const AVOutputFormat *optr = NULL;

    PyObject* formats = PySet_New(NULL);

#if LIBAVFORMAT_VERSION_INT >= AV_VERSION_INT(58, 9, 100)
    void *opaque = NULL;
    while ((iptr = av_demuxer_iterate(&opaque))) {
        PySet_Add(formats, PyUnicode_FromString(iptr->name));
    }

    opaque = NULL;
    while ((optr = av_muxer_iterate(&opaque))) {
        PySet_Add(formats, PyUnicode_FromString(optr->name));
    }
#else
    while ((iptr = av_iformat_next(iptr))) {
        PySet_Add(formats, PyUnicode_FromString(iptr->name));
    }

    while ((optr = av_oformat_next(optr))) {
        PySet_Add(formats, PyUnicode_FromString(optr->name));
    }
#endif

    return formats;
}
