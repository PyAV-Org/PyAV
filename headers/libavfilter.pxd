

cdef extern from "libavfilter/avfiltergraph.h":
    pass
    
cdef extern from "libavfilter/buffersink.h":
    pass
    
cdef extern from "libavfilter/buffersrc.h":
    pass

cdef extern from "libavfilter/avfilter.h":

    cdef void avfilter_register_all()
    
    # http://ffmpeg.org/doxygen/trunk/structAVFilter.html
    cdef struct AVFilter:
        pass
    
    # http://ffmpeg.org/doxygen/trunk/structAVFilterContext.html
    cdef struct AVFilterContext:
        pass
    # http://ffmpeg.org/doxygen/trunk/structAVFilterGraph.html
    cdef struct AVFilterGraph:
        pass
        
    # http://ffmpeg.org/doxygen/trunk/structAVFilterInOut.html
    cdef struct AVFilterInOut:
        char *name
        AVFilterContext* filter_ctx
        int pad_idx
        AVFilterInOut* next
    
    # http://ffmpeg.org/doxygen/trunk/structAVABufferSinkParams.html
    ctypedef struct AVABufferSinkParams:
        AVSampleFormat *sample_fmts
         
         
    cdef AVABufferSinkParams* av_abuffersink_params_alloc()
    
    cdef AVFilter* avfilter_get_by_name(char *name)
    
    cdef AVFilterInOut* avfilter_inout_alloc()
    
    cdef AVFilterGraph* avfilter_graph_alloc()
    cdef void avfilter_graph_free(AVFilterGraph **graph)
    
    cdef int avfilter_graph_create_filter(
        AVFilterContext **filt_ctx,
        AVFilter *filter, 
        char *name,
        char *args,
        void *opaque,
        AVFilterGraph *graph_ctx
    )
    
    cdef int avfilter_graph_parse(
        AVFilterGraph *graph,
        char *filters,
        AVFilterInOut **inputs,
        AVFilterInOut **outputs,
        void* log_ctx 
    )
    
    cdef int avfilter_graph_config(
        AVFilterGraph* graphctx,
        void* log_ctx
    )
    
    
    