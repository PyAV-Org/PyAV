from libc.string cimport memcpy

from av.audio.frame cimport AudioFrame, alloc_audio_frame
from av.dictionary cimport _Dictionary
from av.dictionary import Dictionary
from av.error cimport err_check
from av.filter.pad cimport alloc_filter_pads
from av.frame cimport Frame
from av.utils cimport avrational_to_fraction
from av.video.frame cimport VideoFrame, alloc_video_frame


cdef object _cinit_sentinel = object()


cdef FilterContext wrap_filter_context(Graph graph, Filter filter, lib.AVFilterContext *ptr):
    cdef FilterContext self = FilterContext(_cinit_sentinel)
    self.graph = graph
    self.filter = filter
    self.ptr = ptr
    return self


cdef class FilterContext(object):

    def __cinit__(self, sentinel):
        if sentinel is not _cinit_sentinel:
            raise RuntimeError('cannot construct FilterContext')

    def __repr__(self):
        return '<av.FilterContext %s of %r at 0x%x>' % (
            (repr(self.ptr.name) if self.ptr.name != NULL else '<NULL>') if self.ptr != NULL else 'None',
            self.filter.ptr.name if self.filter and self.filter.ptr != NULL else None,
            id(self),
        )

    property name:
        def __get__(self):
            if self.ptr.name != NULL:
                return self.ptr.name

    property inputs:
        def __get__(self):
            if self._inputs is None:
                self._inputs = alloc_filter_pads(self.filter, self.ptr.input_pads, True, self)
            return self._inputs

    property outputs:
        def __get__(self):
            if self._outputs is None:
                self._outputs = alloc_filter_pads(self.filter, self.ptr.output_pads, False, self)
            return self._outputs

    def init(self, args=None, **kwargs):

        if self.inited:
            raise ValueError('already inited')
        if args and kwargs:
            raise ValueError('cannot init from args and kwargs')

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
            raise ValueError('unused config: %s' % ', '.join(sorted(dict_)))

    def link_to(self, FilterContext input_, int output_idx=0, int input_idx=0):
        err_check(lib.avfilter_link(self.ptr, output_idx, input_.ptr, input_idx))

    def push(self, Frame frame):

        if frame is None:
            err_check(lib.av_buffersrc_write_frame(self.ptr, NULL))
            return
        elif self.filter.name in ('abuffer', 'buffer'):
            err_check(lib.av_buffersrc_write_frame(self.ptr, frame.ptr))
            return

        # Delegate to the input.
        if len(self.inputs) != 1:
            raise ValueError('cannot delegate push without single input; found %d' % len(self.inputs))
        if not self.inputs[0].link:
            raise ValueError('cannot delegate push without linked input')
        self.inputs[0].linked.context.push(frame)

    def pull(self):

        cdef Frame frame
        if self.filter.name == 'buffersink':
            frame = alloc_video_frame()
        elif self.filter.name == 'abuffersink':
            frame = alloc_audio_frame()
        else:
            # Delegate to the output.
            if len(self.outputs) != 1:
                raise ValueError('cannot delegate pull without single output; found %d' % len(self.outputs))
            if not self.outputs[0].link:
                raise ValueError('cannot delegate pull without linked output')
            return self.outputs[0].linked.context.pull()

        self.graph.configure()

        err_check(lib.av_buffersink_get_frame(self.ptr, frame.ptr))
        frame._init_user_attributes()
        frame.time_base = avrational_to_fraction(&self.ptr.inputs[0].time_base)
        return frame
