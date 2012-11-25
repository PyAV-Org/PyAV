cimport libav as lib

from .utils cimport err_check
from .utils import Error


cdef class Context(object):
    
    def __cinit__(self, name, mode='r'):
        
        self.name = name
        self.mode = mode
        self.ptr = NULL
        
        if mode == 'r':
            err_check(lib.avformat_open_input(&self.ptr, name, NULL, NULL))
        
        else:
            raise ValueError('mode must be "r"')
        
        # Make sure we have stream info.
        err_check(lib.avformat_find_stream_info(self.ptr, NULL))
    
    def __dealloc__(self):
        
        if self.ptr != NULL:
            if self.mode == 'r':
                # Frees and sets contents to NULL.
                lib.avformat_close_input(&self.ptr)
    
    def dump(self):
        lib.av_dump_format(self.ptr, 0, self.name, self.mode == 'w');



# Handy alias.
open = Context
