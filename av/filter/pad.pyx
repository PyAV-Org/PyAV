from av.filter.link cimport wrap_filter_link


cdef object _cinit_sentinel = object()


cdef class FilterPad:
    def __cinit__(self, sentinel):
        if sentinel is not _cinit_sentinel:
            raise RuntimeError("cannot construct FilterPad")

    def __repr__(self):
        _filter = self.filter.name
        _io = "inputs" if self.is_input else "outputs"

        return f"<av.FilterPad {_filter}.{_io}[{self.index}]: {self.name} ({self.type})>"

    @property
    def is_output(self):
        return not self.is_input

    @property
    def name(self):
        return lib.avfilter_pad_get_name(self.base_ptr, self.index)

    @property
    def type(self):
        """
        The media type of this filter pad.

        Examples: `'audio'`, `'video'`, `'subtitle'`.

        :type: str
        """
        return lib.av_get_media_type_string(lib.avfilter_pad_get_type(self.base_ptr, self.index))


cdef class FilterContextPad(FilterPad):
    def __repr__(self):
        _filter = self.filter.name
        _io = "inputs" if self.is_input else "outputs"
        context = self.context.name

        return f"<av.FilterContextPad {_filter}.{_io}[{self.index}] of {context}: {self.name} ({self.type})>"

    @property
    def link(self):
        if self._link:
            return self._link
        cdef lib.AVFilterLink **links = self.context.ptr.inputs if self.is_input else self.context.ptr.outputs
        cdef lib.AVFilterLink *link = links[self.index]
        if not link:
            return
        self._link = wrap_filter_link(self.context.graph, link)
        return self._link

    @property
    def linked(self):
        cdef FilterLink link = self.link
        if link:
            return link.input if self.is_input else link.output


cdef tuple alloc_filter_pads(Filter filter, const lib.AVFilterPad *ptr, bint is_input, FilterContext context=None):
    if not ptr:
        return ()

    pads = []

    # We need to be careful and check our bounds if we know what they are,
    # since the arrays on a AVFilterContext are not NULL terminated.
    cdef int i = 0
    cdef int count
    if context is None:
        # This is a custom function defined using a macro in avfilter.pxd. Its usage
        # can be changed after we stop supporting FFmpeg < 5.0.
        count = lib.pyav_get_num_pads(filter.ptr, not is_input, ptr)
    else:
        count = (context.ptr.nb_inputs if is_input else context.ptr.nb_outputs)

    cdef FilterPad pad
    while (i < count):
        pad = FilterPad(_cinit_sentinel) if context is None else FilterContextPad(_cinit_sentinel)
        pads.append(pad)
        pad.filter = filter
        pad.context = context
        pad.is_input = is_input
        pad.base_ptr = ptr
        pad.index = i
        i += 1

    return tuple(pads)
