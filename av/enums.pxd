
cdef class EnumType(type):

    cdef readonly str name
    cdef readonly tuple names
    cdef readonly tuple values

    cdef readonly bint is_flags
    cdef readonly bint allow_multi_flags
    cdef readonly bint allow_user_create

    cdef _by_name
    cdef _by_value
    cdef _all

    cdef _init(self, name, items,
        bint is_flags,
        bint allow_multi_flags,
        bint allow_user_create,
    )
    cdef _create(self, name, value, by_value_only=*)
    cdef _get_multi_flags(self, long value)
    cdef _get(self, long value, bint create=*)


cpdef EnumType define_enum(name, items,
    bint is_flags=*,
    bint allow_multi_flags=*,
    bint allow_user_create=*,
)
