from libc.stdint cimport uint8_t

cimport libav as lib

cdef class FilterContext(object):

    cdef lib.AVFilterContext *buffersink_ctx
    cdef lib.AVFilterContext *buffersrc_ctx
    
    cdef lib.AVFilterGraph *filter_graph
    
    cdef lib.AVFilter *abuffersrc
    cdef lib.AVFilter *abuffersink