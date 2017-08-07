cimport libav as lib


cdef class BaseOption(object):

    cdef lib.AVOption *ptr


cdef class Option(BaseOption):

    cdef readonly tuple choices


cdef class OptionChoice(BaseOption):

    cdef readonly bint is_default


cdef Option wrap_option(tuple choices, lib.AVOption *ptr)

cdef OptionChoice wrap_option_choice(lib.AVOption *ptr, bint is_default)
