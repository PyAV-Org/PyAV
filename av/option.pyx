cimport libav as lib


cdef object _cinit_sentinel = object()

cdef Option wrap_option(tuple choices, lib.AVOption *ptr):
    if ptr == NULL:
        return None
    cdef Option obj = Option(_cinit_sentinel)
    obj.ptr = ptr
    obj.choices = choices
    return obj


cdef dict _TYPE_NAMES = {
    lib.AV_OPT_TYPE_FLAGS: 'FLAGS',
    lib.AV_OPT_TYPE_INT: 'INT',
    lib.AV_OPT_TYPE_INT64: 'INT64',
    lib.AV_OPT_TYPE_DOUBLE: 'DOUBLE',
    lib.AV_OPT_TYPE_FLOAT: 'FLOAT',
    lib.AV_OPT_TYPE_STRING: 'STRING',
    lib.AV_OPT_TYPE_RATIONAL: 'RATIONAL',
    lib.AV_OPT_TYPE_BINARY: 'BINARY',
    lib.AV_OPT_TYPE_DICT: 'DICT',
    #lib.AV_OPT_TYPE_UINT64: 'UINT64', # Added recently, and not yet used AFAICT.
    lib.AV_OPT_TYPE_CONST: 'CONST',
    lib.AV_OPT_TYPE_IMAGE_SIZE: 'IMAGE_SIZE',
    lib.AV_OPT_TYPE_PIXEL_FMT: 'PIXEL_FMT',
    lib.AV_OPT_TYPE_SAMPLE_FMT: 'SAMPLE_FMT',
    lib.AV_OPT_TYPE_VIDEO_RATE: 'VIDEO_RATE',
    lib.AV_OPT_TYPE_DURATION: 'DURATION',
    lib.AV_OPT_TYPE_COLOR: 'COLOR',
    lib.AV_OPT_TYPE_CHANNEL_LAYOUT: 'CHANNEL_LAYOUT',
    lib.AV_OPT_TYPE_BOOL: 'BOOL',
}


cdef class Option(object):

    def __cinit__(self, sentinel):
        if sentinel != _cinit_sentinel:
            raise RuntimeError('Cannot construct av.Option')

    property name:
        def __get__(self):
            return self.ptr.name

    property type:
        def __get__(self):
            return _TYPE_NAMES.get(self.ptr.type)

    property offset:
        """
        This can be used to find aliases of an option.
        Options in a particular descriptor with the same offset are aliases.
        """
        def __get__(self):
            return self.ptr.offset

    property default:
        def __get__(self):
            if self.ptr.type in (lib.AV_OPT_TYPE_FLAGS, lib.AV_OPT_TYPE_INT,
                                 lib.AV_OPT_TYPE_INT64, lib.AV_OPT_TYPE_PIXEL_FMT,
                                 lib.AV_OPT_TYPE_SAMPLE_FMT, lib.AV_OPT_TYPE_DURATION,
                                 lib.AV_OPT_TYPE_CHANNEL_LAYOUT, lib.AV_OPT_TYPE_BOOL):
                return self.ptr.default_val.i64
            if self.ptr.type in (lib.AV_OPT_TYPE_DOUBLE, lib.AV_OPT_TYPE_FLOAT,
                                 lib.AV_OPT_TYPE_RATIONAL):
                return self.ptr.default_val.dbl
            if self.ptr.type in (lib.AV_OPT_TYPE_STRING, lib.AV_OPT_TYPE_BINARY,
                                 lib.AV_OPT_TYPE_IMAGE_SIZE, lib.AV_OPT_TYPE_VIDEO_RATE,
                                 lib.AV_OPT_TYPE_COLOR):
                return self.ptr.default_val.str if self.ptr.default_val.str != NULL else ''

    property min:
        def __get__(self):
            return self.ptr.min

    property max:
        def __get__(self):
            return self.ptr.max

    property help:
        def __get__(self):
            return self.ptr.help if self.ptr.help != NULL else ''

    def __repr__(self):
        return '<av.%s %s at 0x%x>' % (self.__class__.__name__, self.name, id(self))


cdef OptionChoice wrap_option_choice(lib.AVOption *ptr):
    if ptr == NULL:
        return None
    cdef OptionChoice obj = OptionChoice(_cinit_sentinel)
    obj.ptr = ptr
    return obj


cdef class OptionChoice(object):
    """
    Represents AV_OPT_TYPE_CONST options which are essentially
    choices of non-const option with same unit.
    """

    def __cinit__(self, sentinel):
        if sentinel != _cinit_sentinel:
            raise RuntimeError('Cannot construct av.OptionChoice')

    property name:
        def __get__(self):
            return self.ptr.name

    property help:
        def __get__(self):
            return self.ptr.help if self.ptr.help != NULL else ''

    property value:
        def __get__(self):
            return self.ptr.default_val.i64

    def __repr__(self):
        return '<av.%s %s at 0x%x>' % (self.__class__.__name__, self.name, id(self))
