from libc.stdint cimport uint8_t

cimport libav as lib
cimport av.codec

cdef class FilterContext(object):

    cdef lib.AVFilterContext *buffersink_ctx
    cdef lib.AVFilterContext *buffersrc_ctx
    
    cdef lib.AVFilterGraph *filter_graph
    
    cdef lib.AVABufferSinkParams *abuffersink_params
    
    cdef lib.AVFilter *abuffersrc
    cdef lib.AVFilter *abuffersink
    
    cdef lib.AVFilterInOut *outputs
    cdef lib.AVFilterInOut *inputs
    
    cdef av.codec.Codec codec
   