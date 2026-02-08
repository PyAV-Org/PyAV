cdef extern from "libavfilter/avfilter.h" nogil:
    cdef int avfilter_version()
    cdef char* avfilter_configuration()
    cdef char* avfilter_license()

    cdef struct AVFilterPad:
        pass

    const char* avfilter_pad_get_name(const AVFilterPad *pads, int index)
    AVMediaType avfilter_pad_get_type(const AVFilterPad *pads, int index)

    cdef unsigned avfilter_filter_pad_count(const AVFilter *filter, int is_output)

    cdef struct AVFilter:
        const char *name
        const char *description
        const AVFilterPad *inputs
        const AVFilterPad *outputs
        const AVClass *priv_class
        int flags

    cdef AVFilter* avfilter_get_by_name(const char *name)
    cdef const AVFilter* av_filter_iterate(void **opaque)

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

    cdef struct AVFilterGraph:
        int nb_filters
        AVFilterContext **filters

    cdef struct AVFilterInOut:
        char *name
        AVFilterContext *filter_ctx
        int pad_idx
        AVFilterInOut *next

    cdef AVFilterGraph* avfilter_graph_alloc()
    cdef void avfilter_graph_free(AVFilterGraph **ptr)
    cdef AVFilterContext* avfilter_graph_alloc_filter(
        AVFilterGraph *graph,
        const AVFilter *filter,
        const char *name
    )
    cdef int avfilter_graph_create_filter(
        AVFilterContext **filt_ctx,
        AVFilter *filt,
        const char *name,
        const char *args,
        void *opaque,
        AVFilterGraph *graph_ctx
    )
    cdef int avfilter_link(
        AVFilterContext *src,
        unsigned int srcpad,
        AVFilterContext *dst,
        unsigned int dstpad
    )
    cdef int avfilter_graph_config(AVFilterGraph *graph, void *logctx)
    int avfilter_process_command(
        AVFilterContext *filter, const char *cmd, const char *arg, char *res,
        int res_len, int flags,
    )

cdef extern from "libavfilter/buffersink.h" nogil:
    cdef void av_buffersink_set_frame_size(AVFilterContext *ctx, unsigned frame_size)
    int av_buffersink_get_frame(AVFilterContext *ctx, AVFrame *frame)

cdef extern from "libavfilter/buffersrc.h" nogil:
    int av_buffersrc_write_frame(AVFilterContext *ctx, const AVFrame *frame)
