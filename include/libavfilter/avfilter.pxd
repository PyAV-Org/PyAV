
cdef extern from "libavfilter/avfilter.h" nogil:
    
    cdef void avfilter_register_all()

    cdef struct AVFilterPad:

        const char *name
        AVMediaType type


    cdef struct AVFilter:

        AVClass *priv_class

        const char *name
        const char *description

        const int flags
        
        const AVFilterPad *inputs
        const AVFilterPad *outputs


    cdef AVFilter* avfilter_get_by_name(const char *name)


    cdef struct AVFilterContext:

        AVClass *av_class
        AVFilter *filter

        char *name

        unsigned int input_count
        AVFilterPad *input_pads

        unsigned int output_count
        AVFilterPad *output_pads


    cdef struct AVFilterBuffer:

        unsigned int refcount

        int w
        int h

    cdef struct AVFilterBufferRef:

        AVFilterBuffer *buf

        uint8_t **data
        int *linesize
        int format

        int64_t pts
        int64_t pos
        int perms
        AVMediaType type
        uint8_t **extended_data
