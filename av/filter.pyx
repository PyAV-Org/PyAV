from libc.stdint cimport uint8_t

cimport libav as lib


cdef class FilterContext(object):
    
    def __dealloc__(self):
        
        lib.avfilter_graph_free(&self.filter_graph)
    
    def __init__(self, filters_descr):
        print filters_descr
        
        self.abuffersrc = lib.avfilter_get_by_name("abuffer")
        self.abuffersink = lib.avfilter_get_by_name("abuffersink")
        
        
        self.filter_graph = lib.avfilter_graph_alloc()