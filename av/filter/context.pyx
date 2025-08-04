import weakref

from av.audio.frame cimport alloc_audio_frame
from av.dictionary cimport _Dictionary
from av.dictionary import Dictionary
from av.error cimport err_check
from av.filter.link cimport alloc_filter_pads
from av.frame cimport Frame
from av.utils cimport avrational_to_fraction
from av.video.frame cimport alloc_video_frame


cdef object _cinit_sentinel = object()


cdef FilterContext wrap_filter_context(Graph graph, Filter filter, lib.AVFilterContext *ptr):
    cdef FilterContext self = FilterContext(_cinit_sentinel)
    self._graph = weakref.ref(graph)
    self.filter = filter
    self.ptr = ptr
    return self


cdef class FilterContext:
    def __cinit__(self, sentinel):
        if sentinel is not _cinit_sentinel:
            raise RuntimeError("cannot construct FilterContext")

    def __repr__(self):
        if self.ptr != NULL:
            name = repr(self.ptr.name) if self.ptr.name != NULL else "<NULL>"
        else:
            name = "None"

        parent = self.filter.ptr.name if self.filter and self.filter.ptr != NULL else None
        return f"<av.FilterContext {name} of {parent!r} at 0x{id(self):x}>"

    @property
    def name(self):
        if self.ptr.name != NULL:
            return self.ptr.name

    @property
    def inputs(self):
        if self._inputs is None:
            self._inputs = alloc_filter_pads(self.filter, self.ptr.input_pads, True, self)
        return self._inputs

    @property
    def outputs(self):
        if self._outputs is None:
            self._outputs = alloc_filter_pads(self.filter, self.ptr.output_pads, False, self)
        return self._outputs

    def init(self, args=None, **kwargs):
        if self.inited:
            raise ValueError("already inited")
        if args and kwargs:
            raise ValueError("cannot init from args and kwargs")

        cdef _Dictionary dict_ = None
        cdef char *c_args = NULL
        if args or not kwargs:
            if args:
                c_args = args
            err_check(lib.avfilter_init_str(self.ptr, c_args))
        else:
            dict_ = Dictionary(kwargs)
            err_check(lib.avfilter_init_dict(self.ptr, &dict_.ptr))

        self.inited = True
        if dict_:
            raise ValueError(f"unused config: {', '.join(sorted(dict_))}")

    def link_to(self, FilterContext input_, int output_idx=0, int input_idx=0):
        err_check(lib.avfilter_link(self.ptr, output_idx, input_.ptr, input_idx))
    
    @property
    def graph(self):
        if (graph := self._graph()):
            return graph
        else:
            raise RuntimeError("graph is unallocated")

    def push(self, Frame frame):
        cdef int res

        if frame is None:
            with nogil:
                res = lib.av_buffersrc_write_frame(self.ptr, NULL)
            err_check(res)
            return
        elif self.filter.name in ("abuffer", "buffer"):
            with nogil:
                res = lib.av_buffersrc_write_frame(self.ptr, frame.ptr)
            err_check(res)
            return

        # Delegate to the input.
        if len(self.inputs) != 1:
            raise ValueError(
                f"cannot delegate push without single input; found {len(self.inputs)}"
            )
        if not self.inputs[0].link:
            raise ValueError("cannot delegate push without linked input")
        self.inputs[0].linked.context.push(frame)

    def pull(self):
        cdef Frame frame
        cdef int res

        if self.filter.name == "buffersink":
            frame = alloc_video_frame()
        elif self.filter.name == "abuffersink":
            frame = alloc_audio_frame()
        else:
            # Delegate to the output.
            if len(self.outputs) != 1:
                raise ValueError(
                    f"cannot delegate pull without single output; found {len(self.outputs)}"
                )
            if not self.outputs[0].link:
                raise ValueError("cannot delegate pull without linked output")
            return self.outputs[0].linked.context.pull()

        self.graph.configure()

        with nogil:
            res = lib.av_buffersink_get_frame(self.ptr, frame.ptr)
        err_check(res)

        frame._init_user_attributes()
        frame.time_base = avrational_to_fraction(&self.ptr.inputs[0].time_base)
        return frame
