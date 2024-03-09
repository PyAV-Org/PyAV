
cdef extern from "libavfilter/avfilter.h" nogil:
    """
    #if (LIBAVFILTER_VERSION_INT >= 525156)
        // avfilter_filter_pad_count is available since version 8.3.100 of libavfilter (FFmpeg 5.0)
        #define _avfilter_get_num_pads(filter, is_output, pads) (avfilter_filter_pad_count(filter, is_output))
    #else
        // avfilter_filter_pad_count has been deprecated as of version 8.3.100 of libavfilter (FFmpeg 5.0)
        #define _avfilter_get_num_pads(filter, is_output, pads) (avfilter_pad_count(pads))
    #endif
    """
    cdef int   avfilter_version()
    cdef char* avfilter_configuration()
    cdef char* avfilter_license()

    cdef struct AVFilterPad:
        # This struct is opaque.
        pass

    const char* avfilter_pad_get_name(const AVFilterPad *pads, int index)
    AVMediaType avfilter_pad_get_type(const AVFilterPad *pads, int index)

    int pyav_get_num_pads "_avfilter_get_num_pads" (const AVFilter *filter, int is_output, const AVFilterPad *pads)

    cdef struct AVFilter:

        AVClass *priv_class

        const char *name
        const char *description

        const int flags

        const AVFilterPad *inputs
        const AVFilterPad *outputs
        int (*process_command)(AVFilterContext *, const char *cmd, const char *arg, char *res, int res_len, int flags)

    cdef enum:
        AVFILTER_FLAG_DYNAMIC_INPUTS
        AVFILTER_FLAG_DYNAMIC_OUTPUTS
        AVFILTER_FLAG_SLICE_THREADS
        AVFILTER_FLAG_SUPPORT_TIMELINE_GENERIC
        AVFILTER_FLAG_SUPPORT_TIMELINE_INTERNAL

    cdef AVFilter* avfilter_get_by_name(const char *name)
    cdef const AVFilter* av_filter_iterate(void **opaque)

    cdef struct AVFilterLink  # Defined later.

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
    cdef AVClass* avfilter_get_class()

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

    # custom
    cdef set pyav_get_available_filters()


cdef extern from "libavfilter/buffersink.h" nogil:
    cdef void av_buffersink_set_frame_size(AVFilterContext *ctx, unsigned frame_size)
