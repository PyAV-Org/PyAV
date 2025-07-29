import warnings
from fractions import Fraction

from av.audio.format cimport AudioFormat
from av.audio.frame cimport AudioFrame
from av.audio.layout cimport AudioLayout
from av.error cimport err_check
from av.filter.context cimport FilterContext, wrap_filter_context
from av.filter.filter cimport Filter, wrap_filter
from av.video.format cimport VideoFormat
from av.video.frame cimport VideoFrame


cdef class Graph:
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
            return "%s_%s" % (name, count)
        else:
            return name

    cpdef configure(self, bint auto_buffer=True, bint force=False):
        if self.configured and not force:
            return

        err_check(lib.avfilter_graph_config(self.ptr, NULL))
        self.configured = True

        # We get auto-inserted stuff here.
        self._auto_register()

    def link_nodes(self, *nodes):
        """
        Links nodes together for simple filter graphs.
        """
        for c, n in zip(nodes, nodes[1:]):
            c.link_to(n)
        return self

    def add(self, filter, args=None, **kwargs):
        cdef Filter cy_filter
        if isinstance(filter, str):
            cy_filter = Filter(filter)
        elif isinstance(filter, Filter):
            cy_filter = filter
        else:
            raise TypeError("filter must be a string or Filter")

        cdef str name = self._get_unique_name(kwargs.pop("name", None) or cy_filter.name)

        cdef lib.AVFilterContext *ptr = lib.avfilter_graph_alloc_filter(self.ptr, cy_filter.ptr, name)
        if not ptr:
            raise RuntimeError("Could not allocate AVFilterContext")

        # Manually construct this context (so we can return it).
        cdef FilterContext ctx = wrap_filter_context(self, cy_filter, ptr)
        ctx.init(args, **kwargs)
        self._register_context(ctx)

        # There might have been automatic contexts added (e.g. resamplers,
        # fifos, and scalers). It is more likely to see them after the graph
        # is configured, but we want to be safe.
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

    def add_buffer(self, template=None, width=None, height=None, format=None, name=None, time_base=None):
        if template is not None:
            if width is None:
                width = template.width
            if height is None:
                height = template.height
            if format is None:
                format = template.format
            if time_base is None:
                time_base = template.time_base

        if width is None:
            raise ValueError("missing width")
        if height is None:
            raise ValueError("missing height")
        if format is None:
            raise ValueError("missing format")
        if time_base is None:
            warnings.warn("missing time_base. Guessing 1/1000 time base. "
                          "This is deprecated and may be removed in future releases.",
                          DeprecationWarning)
            time_base = Fraction(1, 1000)

        return self.add(
            "buffer",
            name=name,
            video_size=f"{width}x{height}",
            pix_fmt=str(int(VideoFormat(format))),
            time_base=str(time_base),
            pixel_aspect="1/1",
        )

    def add_abuffer(self, template=None, sample_rate=None, format=None, layout=None, channels=None, name=None, time_base=None):
        """
        Convenience method for adding `abuffer <https://ffmpeg.org/ffmpeg-filters.html#abuffer>`_.
        """

        if template is not None:
            if sample_rate is None:
                sample_rate = template.sample_rate
            if format is None:
                format = template.format
            if layout is None:
                layout = template.layout.name
            if channels is None:
                channels = template.channels
            if time_base is None:
                time_base = template.time_base

        if sample_rate is None:
            raise ValueError("missing sample_rate")
        if format is None:
            raise ValueError("missing format")
        if layout is None and channels is None:
            raise ValueError("missing layout or channels")
        if time_base is None:
            time_base = Fraction(1, sample_rate)

        kwargs = dict(
            sample_rate=str(sample_rate),
            sample_fmt=AudioFormat(format).name,
            time_base=str(time_base),
        )
        if layout:
            kwargs["channel_layout"] = AudioLayout(layout).name
        if channels:
            kwargs["channels"] = str(channels)

        return self.add("abuffer", name=name, **kwargs)

    def set_audio_frame_size(self, frame_size):
        """
        Set the audio frame size for the graphs `abuffersink`.
        See `av_buffersink_set_frame_size <https://ffmpeg.org/doxygen/trunk/group__lavfi__buffersink.html#ga359d7d1e42c27ca14c07559d4e9adba7>`_.
        """
        if not self.configured:
            raise ValueError("graph not configured")
        sinks = self._context_by_type.get("abuffersink", [])
        if not sinks:
            raise ValueError("missing abuffersink filter")
        for sink in sinks:
            lib.av_buffersink_set_frame_size((<FilterContext>sink).ptr, frame_size)

    def push(self, frame):
        if frame is None:
            contexts = self._context_by_type.get("buffer", []) + self._context_by_type.get("abuffer", [])
        elif isinstance(frame, VideoFrame):
            contexts = self._context_by_type.get("buffer", [])
        elif isinstance(frame, AudioFrame):
            contexts = self._context_by_type.get("abuffer", [])
        else:
            raise ValueError(f"can only AudioFrame, VideoFrame or None; got {type(frame)}")

        for ctx in contexts:
            ctx.push(frame)

    def vpush(self, VideoFrame frame):
        """Like `push`, but only for VideoFrames."""
        for ctx in self._context_by_type.get("buffer", []):
            ctx.push(frame)


    # TODO: Test complex filter graphs, add `at: int = 0` arg to pull() and vpull().
    def pull(self):
        vsinks = self._context_by_type.get("buffersink", [])
        asinks = self._context_by_type.get("abuffersink", [])

        nsinks = len(vsinks) + len(asinks)
        if nsinks != 1:
            raise ValueError(f"can only auto-pull with single sink; found {nsinks}")

        return (vsinks or asinks)[0].pull()

    def vpull(self):
        """Like `pull`, but only for VideoFrames."""
        vsinks = self._context_by_type.get("buffersink", [])
        nsinks = len(vsinks)
        if nsinks != 1:
            raise ValueError(f"can only auto-pull with single sink; found {nsinks}")

        return vsinks[0].pull()
