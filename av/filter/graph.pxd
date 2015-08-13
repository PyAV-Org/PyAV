cimport libav as lib


cdef class Graph(object):

    cdef lib.AVFilterGraph *ptr
    cdef lib.AVFilterInOut *inputs
    cdef lib.AVFilterInOut *outputs
    
    cdef lib.AVFilterContext *sink_ctx
