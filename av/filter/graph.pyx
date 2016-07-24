from libc.string cimport memcpy

from av.filter.context cimport FilterContext, wrap_filter_context
from av.filter.filter cimport Filter, wrap_filter
from av.utils cimport err_check
from av.video.frame cimport VideoFrame, alloc_video_frame
from av.video.format cimport VideoFormat

cdef class Graph(object):

    def __cinit__(self):

        self.ptr = lib.avfilter_graph_alloc()
        self.configured = False
        self._name_counts = {}

        self._nb_filters_seen = 0
        self._context_by_ptr = {}
        self._context_by_name = {}
        self._context_by_type = {}

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
    
    cpdef configure(self, bint auto_buffer=True, bint force=False):
        if self.configured and not force:
            return

        # if auto_buffer:
        #     for ctx in self._context_by_ptr.itervalues():
        #         for in_ in ctx.inputs:
        #             if not in_.link:
        #                 if in_.type == 'video':
        #                     pass

        err_check(lib.avfilter_graph_config(self.ptr, NULL))
        self.configured = True

        # We get auto-inserted stuff here.
        self._auto_register()
    
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

    # NOTE: Only FFmpeg supports this.
    # def dump(self):
    #     cdef char *buf = lib.avfilter_graph_dump(self.ptr, "")
    #     cdef str ret = buf
    #     lib.av_free(buf)
    #     return ret

    def add(self, filter, args=None, **kwargs):
        
        cdef Filter cy_filter
        if isinstance(filter, basestring):
            cy_filter = Filter(filter)
        elif isinstance(filter, Filter):
            cy_filter = filter
        else:
            raise TypeError("filter must be a string or Filter")
        
        cdef str name = self._get_unique_name(kwargs.pop('name', None) or cy_filter.name)
        
        cdef lib.AVFilterContext *ptr = lib.avfilter_graph_alloc_filter(self.ptr, cy_filter.ptr, name)
        if not ptr:
            raise RuntimeError("Could not allocate AVFilterContext")

        # Manually construct this context (so we can return it).
        cdef FilterContext ctx = wrap_filter_context(self, cy_filter, ptr)
        ctx.init(args, **kwargs)
        self._register_context(ctx)

        # There might have been automatic contexts added (e.g. resamplers,
        # fifos, and scalers). It is more likely to see them after the graph
        # is configured, but we wan't to be safe.
        self._auto_register()

        return ctx

    cdef _register_context(self, FilterContext ctx):
        self._context_by_ptr[<long>ctx.ptr] = ctx
        self._context_by_name[ctx.ptr.name] = ctx
        self._context_by_type.setdefault(ctx.filter.ptr.name, []).append(ctx)

    cdef _auto_register(self):
        cdef int i
        cdef lib.AVFilterContext *c_ctx
        cdef Filter filter_
        cdef FilterContext py_ctx
        # We assume that filters are never removed from the graph. At this
        # point we don't expose that in the API, so we should be okay...
        for i in range(self._nb_filters_seen, self.ptr.nb_filters):
            c_ctx = self.ptr.filters[i]
            if <long>c_ctx in self._context_by_ptr:
                continue
            filter_ = wrap_filter(c_ctx.filter)
            py_ctx = wrap_filter_context(self, filter_, c_ctx)
            self._register_context(py_ctx)
        self._nb_filters_seen = self.ptr.nb_filters
    
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

    def push(self, frame):

        if isinstance(frame, VideoFrame):
            contexts = self._context_by_type.get('buffer', [])
        else:
            raise ValueError('can only push VideoFrame', type(frame))

        if len(contexts) != 1:
            raise ValueError('can only auto-push with single buffer; found %s' % len(contexts))
        
        contexts[0].push(frame)

    def pull(self):

        vsinks = self._context_by_type.get('buffersink', [])
        asinks = self._context_by_type.get('abuffersink', [])

        nsinks = len(vsinks) + len(asinks)
        if nsinks != 1:
            raise ValueError('can only auto-pull with single sink; found %s' % nsinks)

        return (vsinks or asinks)[0].pull()




