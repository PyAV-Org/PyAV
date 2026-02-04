import weakref

import cython
import cython.cimports.libav as lib
from cython.cimports.av.audio.frame import alloc_audio_frame
from cython.cimports.av.dictionary import Dictionary
from cython.cimports.av.error import err_check
from cython.cimports.av.filter.link import alloc_filter_pads
from cython.cimports.av.frame import Frame
from cython.cimports.av.utils import avrational_to_fraction
from cython.cimports.av.video.frame import alloc_video_frame

_cinit_sentinel = cython.declare(object, object())


@cython.cfunc
def wrap_filter_context(
    graph: Graph, filter: Filter, ptr: cython.pointer[lib.AVFilterContext]
) -> FilterContext:
    self: FilterContext = FilterContext(_cinit_sentinel)
    self._graph = weakref.ref(graph)
    self.filter = filter
    self.ptr = ptr
    return self


@cython.cclass
class FilterContext:
    def __cinit__(self, sentinel):
        if sentinel is not _cinit_sentinel:
            raise RuntimeError("cannot construct FilterContext")

    def __repr__(self):
        if self.ptr != cython.NULL:
            name = repr(self.ptr.name) if self.ptr.name != cython.NULL else "<NULL>"
        else:
            name = "None"

        parent = (
            self.filter.ptr.name
            if self.filter and self.filter.ptr != cython.NULL
            else None
        )
        return f"<av.FilterContext {name} of {parent!r} at 0x{id(self):x}>"

    @property
    def name(self):
        if self.ptr.name != cython.NULL:
            return self.ptr.name

    @property
    def inputs(self):
        if self._inputs is None:
            self._inputs = alloc_filter_pads(
                self.filter, self.ptr.input_pads, True, self
            )
        return self._inputs

    @property
    def outputs(self):
        if self._outputs is None:
            self._outputs = alloc_filter_pads(
                self.filter, self.ptr.output_pads, False, self
            )
        return self._outputs

    def init(self, args=None, **kwargs):
        if self.inited:
            raise ValueError("already inited")
        if args and kwargs:
            raise ValueError("cannot init from args and kwargs")

        dict_: Dictionary = None
        c_args: cython.p_char = cython.NULL
        if args or not kwargs:
            if args:
                c_args = args
            err_check(lib.avfilter_init_str(self.ptr, c_args))
        else:
            dict_ = Dictionary(kwargs)
            err_check(lib.avfilter_init_dict(self.ptr, cython.address(dict_.ptr)))

        self.inited = True
        if dict_:
            raise ValueError(f"unused config: {', '.join(sorted(dict_))}")

    def link_to(
        self,
        input_: FilterContext,
        output_idx: cython.int = 0,
        input_idx: cython.int = 0,
    ):
        err_check(lib.avfilter_link(self.ptr, output_idx, input_.ptr, input_idx))

    @property
    def graph(self):
        if graph := self._graph():
            return graph
        else:
            raise RuntimeError("graph is unallocated")

    def push(self, frame: Frame | None):
        res: cython.int

        if frame is None:
            with cython.nogil:
                res = lib.av_buffersrc_write_frame(self.ptr, cython.NULL)
            err_check(res)
            return
        elif self.filter.name in ("abuffer", "buffer"):
            with cython.nogil:
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
        frame: Frame
        res: cython.int
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

        with cython.nogil:
            res = lib.av_buffersink_get_frame(self.ptr, frame.ptr)
        err_check(res)

        frame._init_user_attributes()
        frame.time_base = avrational_to_fraction(
            cython.address(self.ptr.inputs[0].time_base)
        )
        return frame

    def process_command(
        self, cmd, arg=None, res_len: cython.int = 1024, flags: cython.int = 0
    ):
        if not cmd:
            raise ValueError("Invalid cmd")

        c_arg: cython.p_char = cython.NULL
        c_cmd: cython.p_char = cmd
        if arg is not None:
            c_arg = arg

        c_res: cython.p_char = cython.NULL
        ret: cython.int
        res_buf: bytearray = None
        view: cython.uchar[:]
        b: bytes
        nul: cython.int

        if res_len > 0:
            res_buf = bytearray(res_len)
            view = res_buf
            c_res = cython.cast(cython.p_char, cython.address(view[0]))

        with cython.nogil:
            ret = lib.avfilter_process_command(
                self.ptr, c_cmd, c_arg, c_res, res_len, flags
            )
        err_check(ret)

        if res_buf is not None:
            b = bytes(res_buf)
            nul = b.find(b"\x00")
            if nul >= 0:
                b = b[:nul]
            if b:
                return b.decode("utf-8", "strict")
        return None
