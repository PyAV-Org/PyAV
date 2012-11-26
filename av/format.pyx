cimport libav as lib

from .utils cimport err_check
from .utils import Error

cimport av.codec


cdef class _AVFormatContextProxy(object):
    def __dealloc__(self):
        if self.ptr != NULL:
            lib.avformat_close_input(&self.ptr)


cdef class Context(object):
    
    def __cinit__(self, name, mode='r'):
        
        self.name = name
        self.mode = mode
        self.proxy = _AVFormatContextProxy()
        
        if mode == 'r':
            err_check(lib.avformat_open_input(&self.proxy.ptr, name, NULL, NULL))
        
        else:
            raise ValueError('mode must be "r"')
        
        # Make sure we have stream info.
        err_check(lib.avformat_find_stream_info(self.proxy.ptr, NULL))
    
    def __init__(self, name, mode='r'):
        
        # Build our streams.
        self.streams = tuple(Stream(self, i) for i in range(self.proxy.ptr.nb_streams))
    
    def dump(self):
        lib.av_dump_format(self.proxy.ptr, 0, self.name, self.mode == 'w');


cdef class Stream(object):
    
    def __cinit__(self, Context ctx, int index):
        
        if index < 0 or index > ctx.proxy.ptr.nb_streams:
            raise ValueError('stream index out of range')
        self.ctx_proxy = ctx.proxy
        self.ptr = self.ctx_proxy.ptr.streams[index]
        
        if self.ptr.codec.codec_type == lib.AVMEDIA_TYPE_VIDEO:
            self.type = b'video'
        else:
            self.type = b'unknown'
    
    def __init__(self, Context ctx, int index):
        self.codec = av.codec.Codec(self)
    
    def __repr__(self):
        return '<%s.%s %s/%s at 0x%x>' % (
            self.__class__.__module__,
            self.__class__.__name__,
            self.type,
            self.codec.name,
            id(self),
        )
        


# Handy alias.
open = Context
