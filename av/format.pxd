cimport libav as lib


cdef class ContainerFormat(object):

    cdef readonly str name
    
    cdef lib.AVInputFormat *in_
    cdef lib.AVOutputFormat *out


cdef ContainerFormat build_container_format(lib.AVInputFormat*, lib.AVOutputFormat*)
