from libc.string cimport memcpy

from av.filter.context cimport FilterContext, make_filter_context
from av.filter.filter cimport Filter
from av.utils cimport err_check
from av.video.frame cimport VideoFrame, alloc_video_frame
from av.video.format cimport VideoFormat

cdef class Graph(object):

    def __cinit__(self):
        self.ptr = lib.avfilter_graph_alloc()
        self.configured = False
        self._name_counts = {}
        self._context_by_ptr = {}
        self._context_by_name = {}

    def __dealloc__(self):
        if self.ptr:
            # This frees the graph, filter contexts, links, etc..
            lib.avfilter_graph_free(&self.ptr)
    
    cdef str _get_unique_name(self, str name):
        count = self._name_counts.get(name, 0)
        self._name_counts[name] = count + 1
        if count:
            return '%s_%s' % name
        else:
            return name
    
    cpdef configure(self, bint force=False):
        if force or not self.configured:
            err_check(lib.avfilter_graph_config(self.ptr, NULL))
            self.configured = True
    
    # def parse_string(self, str filter_str):
        # err_check(lib.avfilter_graph_parse2(self.ptr, filter_str, &self.inputs, &self.outputs))
        #
        # cdef lib.AVFilterInOut *input_
        # while input_ != NULL:
        #     print 'in ', input_.pad_idx, (input_.name if input_.name != NULL else ''), input_.filter_ctx.name, input_.filter_ctx.filter.name
        #     input_ = input_.next
        #
        # cdef lib.AVFilterInOut *output
        # while output != NULL:
        #     print 'out', output.pad_idx, (output.name if output.name != NULL else ''), output.filter_ctx.name, output.filter_ctx.filter.name
        #     output = output.next




    def dump(self):
        cdef char *buf = lib.avfilter_graph_dump(self.ptr, "")
        cdef str ret = buf
        lib.av_free(buf)
        return ret

    def add(self, filter, args=None, **kwargs):
        
        cdef Filter c_filter
        if isinstance(filter, basestring):
            c_filter = Filter(filter)
        elif isinstance(filter, Filter):
            c_filter = filter
        else:
            raise TypeError("filter must be a string or Filter")
        
        cdef str name = self._get_unique_name(kwargs.pop('name', None) or c_filter.name)
        
        cdef FilterContext ctx = make_filter_context()
        ctx.graph = self
        ctx.filter = c_filter
        ctx.ptr = lib.avfilter_graph_alloc_filter(self.ptr, c_filter.ptr, name)
        if not ctx.ptr:
            raise RuntimeError("Could not allocate AVFilterContext")
        
        ctx.init(args, **kwargs)
        
        self._context_by_ptr[<long>ctx.ptr] = ctx
        self._context_by_name[name] = ctx
        
        return ctx
    
    def add_buffer(self, template=None, width=None, height=None, format=None, name=None):

        if template is not None:
            if width is None:
                width = template.width
            if height is None:
                height = template.height
            if format is None:
                format = template.format
        
        if width is None:
            raise ValueError('missing width')
        if height is None:
            raise ValueError('missing height')
        if format is None:
            raise ValueError('missing format')
        
        args = "video_size=%dx%d:pix_fmt=%d:time_base=%d/%d:pixel_aspect=%d/%d" % (
            width, height, int(VideoFormat(format)),
            1, 1000,
            1, 1
        )
        
        return self.add('buffer', args, name=name)

