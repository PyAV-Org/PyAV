
cdef extern from "libavfilter/avfilter.h" nogil:

    cdef int   avfilter_version()
    cdef char* avfilter_configuration()
    cdef char* avfilter_license()
    
    cdef void avfilter_register_all()

    cdef struct AVFilterPad:
        # This struct is opaque.
        pass

    const char* avfilter_pad_get_name(const AVFilterPad *pads, int index)
    AVMediaType avfilter_pad_get_type(const AVFilterPad *pads, int index)

    cdef struct AVFilter:

        AVClass *priv_class

        const char *name
        const char *description

        const int flags
        
        const AVFilterPad *inputs
        const AVFilterPad *outputs

    cdef int AVFILTER_FLAG_DYNAMIC_INPUTS
    cdef int AVFILTER_FLAG_DYNAMIC_OUTPUTS
    cdef int AVFILTER_FLAG_SLICE_THREADS
    cdef int AVFILTER_FLAG_SUPPORT_TIMELINE_GENERIC
    cdef int AVFILTER_FLAG_SUPPORT_TIMELINE_INTERNAL

    cdef AVFilter* avfilter_get_by_name(const char *name)

    cdef struct AVFilterLink # Defined later.
    
    cdef struct AVFilterContext:

        AVClass *av_class
        AVFilter *filter

        char *name

        unsigned int nb_inputs
        AVFilterPad *input_pads
        AVFilterLink **inputs
        
        unsigned int nb_outputs
        AVFilterPad *output_pads
        AVFilterLink **outputs

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
        