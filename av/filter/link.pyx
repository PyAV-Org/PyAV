cimport libav as lib

from av.filter.graph cimport Graph


cdef _cinit_sentinel = object()


cdef class FilterLink:

    def __cinit__(self, sentinel):
        if sentinel is not _cinit_sentinel:
            raise RuntimeError("cannot instantiate FilterLink")

    @property
    def input(self):
        if self._input:
            return self._input
        cdef lib.AVFilterContext *cctx = self.ptr.src
        cdef unsigned int i
        for i in range(cctx.nb_outputs):
            if self.ptr == cctx.outputs[i]:
                break
        else:
            raise RuntimeError("could not find link in context")
        ctx = self.graph._context_by_ptr[<long>cctx]
        self._input = ctx.outputs[i]
        return self._input

    @property
    def output(self):
        if self._output:
            return self._output
        cdef lib.AVFilterContext *cctx = self.ptr.dst
        cdef unsigned int i
        for i in range(cctx.nb_inputs):
            if self.ptr == cctx.inputs[i]:
                break
        else:
            raise RuntimeError("could not find link in context")
        try:
            ctx = self.graph._context_by_ptr[<long>cctx]
        except KeyError:
            raise RuntimeError("could not find context in graph", (cctx.name, cctx.filter.name))
        self._output = ctx.inputs[i]
        return self._output


cdef FilterLink wrap_filter_link(Graph graph, lib.AVFilterLink *ptr):
    cdef FilterLink link = FilterLink(_cinit_sentinel)
    link.graph = graph
    link.ptr = ptr
    return link
