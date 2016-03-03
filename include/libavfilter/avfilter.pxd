
cdef extern from "libavfilter/avfilter.h" nogil:

    cdef int   avfilter_version()
    cdef char* avfilter_configuration()
    cdef char* avfilter_license()
    
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

    cdef int avfilter_init_str(AVFilterContext *ctx, const char *args)
    cdef int avfilter_init_dict(AVFilterContext *ctx, AVDictionary **options)
    cdef void avfilter_free(AVFilterContext*)

    cdef struct AVFilterLink:
        
        AVFilterContext *src
        AVFilterPad *srcpad
        AVFilterContext *dst
        AVFilterPad *dstpad
        
        AVMediaType Type
        int w
        int h
        AVRational sample_aspect_ratio
        uint64_t channel_layout
        int sample_rate
        int format
        AVRational time_base
        