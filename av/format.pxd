cimport libav as lib


cdef class ContainerFormat:

    cdef readonly str name

    cdef const lib.AVInputFormat *iptr
    cdef const lib.AVOutputFormat *optr


cdef ContainerFormat build_container_format(const lib.AVInputFormat*, const lib.AVOutputFormat*)
