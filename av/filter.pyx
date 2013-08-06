from libc.stdint cimport uint8_t

cimport libav as lib

cimport av.codec


cdef class FilterContext(object):
    
    def __dealloc__(self):
        
        lib.avfilter_graph_free(&self.filter_graph)

    def setup(self, filters_descr):
        print filters_descr
        
        cdef char *args
        cdef int ret
        
        cdef lib.AVSampleFormat sample_fmts[2]
        
        sample_fmts[0] = self.codec.ctx.sample_fmt
        sample_fmts[1] = lib.AV_SAMPLE_FMT_NONE
        #[self.codec.ctx.sample_fmt,lib.AV_PIX_FMT_NONE]
        
        
        self.abuffersrc = lib.avfilter_get_by_name("abuffer")
        self.abuffersink = lib.avfilter_get_by_name("abuffersink")

        self.outputs = lib.avfilter_inout_alloc()
        self.inputs = lib.avfilter_inout_alloc()
        
        
        
        
        temp_args = "time_base=%i/%i:sample_rate=%i:sample_fmt=%s:channel_layout=%s" 
        
        temp_args = temp_args % (self.codec.time_base.numerator,
                       self.codec.time_base.denominator,
                       self.codec.sample_rate,
                       self.codec.sample_fmt,
                       self.codec.channel_layout)
        
        args = temp_args
#         
#         cdef char args[512]
#         args = targs
#         
        print args
    
        self.filter_graph = lib.avfilter_graph_alloc()
        

        ret = lib.avfilter_graph_create_filter(&self.buffersrc_ctx, #filt_ctx
                                               self.abuffersrc, #filter
                                               "in",#name
                                               args, #args
                                               NULL, #opaque
                                               self.filter_graph)
        if ret < 0:
            raise Exception("Cannot create audio buffer source")
        
        self.abuffersink_params = lib.av_abuffersink_params_alloc()
        
        
        self.abuffersink_params.sample_fmts = sample_fmts
        
        ret = lib.avfilter_graph_create_filter(&self.buffersink_ctx,
                                               self.abuffersink,
                                               "out",
                                               NULL,
                                               self.abuffersink_params,
                                               self.filter_graph)
        
        
        lib.av_free(self.abuffersink_params)
        
        if ret < 0:
            raise Exception("Cannot create audio buffer sink")
        
        # Endpoints for the filter graph.
        self.outputs.name = lib.av_strdup("in")
        self.outputs.filter_ctx = self.buffersrc_ctx
        self.outputs.pad_idx = 0
        self.outputs.next = NULL
        
        self.inputs.name = lib.av_strdup("out")
        self.inputs.filter_ctx = self.buffersink_ctx
        self.inputs.pad_idx = 0
        self.inputs.next = NULL
        
        print "parsing graph"
        ret = lib.avfilter_graph_parse(self.filter_graph, filters_descr,
                                       &self.inputs, &self.outputs, NULL)
        
        if ret < 0:
            raise Exception("Cannot avfilter_graph_parse")
        
        
        ret = lib.avfilter_graph_config(self.filter_graph, NULL)
        
        if ret < 0:
            raise Exception("Cannot avfilter_graph_config")
        
        