cimport libav as lib


cdef class Option(object):

    cdef lib.AVOption *ptr
    cdef readonly tuple choices # choices tuple


cdef class OptionChoice(object):

    cdef lib.AVOption *ptr


cdef Option wrap_option(tuple choices, lib.AVOption *ptr)

cdef OptionChoice wrap_option_choice(lib.AVOption *ptr)

