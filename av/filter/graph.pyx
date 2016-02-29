from libc.string cimport memcpy

from av.filter.context cimport FilterContext, make_filter_context
from av.filter.filter cimport Filter
from av.utils cimport err_check
from av.video.frame cimport VideoFrame, alloc_video_frame


cdef class Graph(object):

    def __cinit__(self):
        
        self.ptr = lib.avfilter_graph_alloc()
        
    
    def _junk(self):
        
        filter_str = "mandelbrot"

        err_check(lib.avfilter_graph_parse2(self.ptr, filter_str, &self.inputs, &self.outputs))

        cdef lib.AVFilterInOut *input_ = self.inputs
        while input_ != NULL:
            print 'in ', input_.pad_idx, (input_.name if input_.name != NULL else ''), input_.filter_ctx.name, input_.filter_ctx.filter.name
            input_ = input_.next

        cdef lib.AVFilterInOut *output = self.outputs
        while output != NULL:
            print 'out', output.pad_idx, (output.name if output.name != NULL else ''), output.filter_ctx.name, output.filter_ctx.filter.name
            output = output.next

        cdef lib.AVFilter *sink = lib.avfilter_get_by_name("buffersink")

        err_check(lib.avfilter_graph_create_filter(
            &self.sink_ctx,
            sink,
            "out",
            "",
            NULL,
            self.ptr
        ))

        lib.avfilter_link(self.outputs[0].filter_ctx, self.outputs[0].pad_idx, self.sink_ctx, 0)

        err_check(lib.avfilter_graph_config(self.ptr, NULL))


    def __dealloc__(self):
        if self.inputs:
            lib.avfilter_inout_free(&self.inputs)
        if self.outputs:
            lib.avfilter_inout_free(&self.outputs)
        if self.ptr:
            lib.avfilter_graph_free(&self.ptr)

    def dump(self):
        cdef char *buf = lib.avfilter_graph_dump(self.ptr, "")
        cdef str ret = buf
        lib.av_free(buf)
        return ret

    def add(self, filter, name=None, args=None, **kwargs):
        
        cdef Filter c_filter
        if isinstance(filter, basestring):
            c_filter = Filter(filter)
        elif isinstance(filter, Filter):
            c_filter = filter
        else:
            raise TypeError("filter must be a string or Filter")
        
        cdef char *c_name = NULL
        if name:
            c_name = name
        
        cdef FilterContext ctx = make_filter_context()
        ctx.graph = self
        ctx.filter = c_filter
        ctx.ptr = lib.avfilter_graph_alloc_filter(self.ptr, c_filter.ptr, c_name)
        if not ctx.ptr:
            raise RuntimeError("Could not allocate AVFilterContext")
        
        ctx.init(args, **kwargs)
        
        return ctx

    def config(self):
        err_check(lib.avfilter_graph_config(self.ptr, NULL))
