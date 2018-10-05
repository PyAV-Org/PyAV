cimport libav as lib

from av.descriptor cimport wrap_avclass


cdef extern from "format-shims.c" nogil:
    cdef lib.AVOutputFormat* pyav_find_output_format(const char *name)


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
            self.optr = pyav_find_output_format(name)

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


formats_available = lib.pyav_get_available_formats()
format_descriptor = wrap_avclass(lib.avformat_get_class())
