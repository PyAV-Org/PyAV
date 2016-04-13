cimport libav as lib

from av.descriptor cimport wrap_avclass


cdef object _cinit_bypass_sentinel = object()

cdef ContainerFormat build_container_format(lib.AVInputFormat* iptr, lib.AVOutputFormat* optr):
    if not iptr and not optr:
        raise ValueError('needs input format or output format')
    cdef ContainerFormat format = ContainerFormat.__new__(ContainerFormat, _cinit_bypass_sentinel)
    format.iptr = iptr
    format.optr = optr
    format.name = optr.name if optr else iptr.name
    return format


cdef class ContainerFormat(object):

    """Descriptor of a container format.

    :param str name: The name of the format.
    :param str mode: ``'r'`` or ``'w'`` for input and output formats; defaults
        to None which will grab either.

    """
    
    def __cinit__(self, name, mode=None):

        if name is _cinit_bypass_sentinel:
            return

        # We need to hold onto the original name because AVInputFormat.name
        # is actually comma-seperated, and so we need to remember which one
        # this was.
        self.name = name

        # Searches comma-seperated names.
        if mode is None or mode == 'r':
            self.iptr = lib.av_find_input_format(name)

        if mode is None or mode == 'w':
            while True:
                self.optr = lib.av_oformat_next(self.optr)
                if not self.optr or self.optr.name == name:
                    break

        if not self.iptr and not self.optr:
            raise ValueError('no container format %r' % name)

    def __repr__(self):
        return '<av.%s %r>' % (self.__class__.__name__, self.name)

    property descriptor:
        def __get__(self):
            if self.iptr:
                return wrap_avclass(self.iptr.priv_class)
            else:
                return wrap_avclass(self.optr.priv_class)

    property options:
        def __get__(self):
            return self.descriptor.options

    property input:
        """An input-only view of this format."""
        def __get__(self):
            if self.iptr == NULL:
                return None
            elif self.optr == NULL:
                return self
            else:
                return build_container_format(self.iptr, NULL)

    property output:
        """An output-only view of this format."""
        def __get__(self):
            if self.optr == NULL:
                return None
            elif self.iptr == NULL:
                return self
            else:
                return build_container_format(NULL, self.optr)

    property is_input:
        def __get__(self):
            return self.iptr != NULL

    property is_output:
        def __get__(self):
            return self.optr != NULL

    property long_name:
        def __get__(self):
            # We prefer the output names since the inputs may represent
            # multiple formats.
            return self.optr.long_name if self.optr else self.iptr.long_name

    property extensions:
        def __get__(self):
            cdef set exts = set()
            if self.iptr and self.iptr.extensions:
                exts.update(self.iptr.extensions.split(','))
            if self.optr and self.optr.extensions:
                exts.update(self.optr.extensions.split(','))
            return exts


names = set()

cdef lib.AVInputFormat *iptr = NULL
while True:
    iptr = lib.av_iformat_next(iptr)
    if not iptr:
        break
    names.add(iptr.name)

cdef lib.AVOutputFormat *optr = NULL
while True:
    optr = lib.av_oformat_next(optr)
    if not optr:
        break
    names.add(optr.name)

