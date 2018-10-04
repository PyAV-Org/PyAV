#include "libavfilter/avfilter.h"

PyObject* pyav_get_available_filters(void)
{
    const AVFilter *ptr = NULL;
    PyObject* filters = PySet_New(NULL);

#if LIBAVFILTER_VERSION_INT >= AV_VERSION_INT(7, 14, 100)
    void *opaque = NULL;
    while ((ptr = av_filter_iterate(&opaque))) {
        PySet_Add(filters, PyUnicode_FromString(ptr->name));
    }
#else
    while ((ptr = avfilter_next(ptr))) {
        PySet_Add(filters, PyUnicode_FromString(ptr->name));
    }
#endif

    return filters;
}
