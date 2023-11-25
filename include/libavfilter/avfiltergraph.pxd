
cdef extern from "libavfilter/avfilter.h" nogil:

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

    cdef int avfilter_graph_parse2(
        AVFilterGraph *graph,
        const char *filter_str,
        AVFilterInOut **inputs,
        AVFilterInOut **outputs
    )

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

    cdef char* avfilter_graph_dump(AVFilterGraph *graph, const char *options)

    cdef void avfilter_inout_free(AVFilterInOut **inout_list)
