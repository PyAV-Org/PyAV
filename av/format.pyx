cimport libav as lib

from .utils cimport err_check, avdict_to_dict, avrational_to_faction
from .utils import Error

cimport av.codec


cdef class ContextProxy(object):

    def __init__(self, bint is_input):
        self.is_input = is_input
    
    def __dealloc__(self):
        if self.ptr != NULL:
            if self.is_input:
                lib.avformat_close_input(&self.ptr)


cdef class Context(object):
    
    def __init__(self, name, mode='r'):
        
        if mode == 'r':
            self.is_input = True
            self.is_output = False
        elif mode == 'w':
            self.is_input = False
            self.is_output = True
            raise NotImplementedError('no output yet')
        else:
            raise ValueError('mode must be "r" or "w"')
        
        self.name = name
        self.mode = mode
        self.proxy = ContextProxy(self.is_input)
        
        if self.is_input:
            err_check(lib.avformat_open_input(&self.proxy.ptr, name, NULL, NULL))
            err_check(lib.avformat_find_stream_info(self.proxy.ptr, NULL))
        
        self.streams = tuple(Stream(self, i) for i in range(self.proxy.ptr.nb_streams))
        self.metadata = avdict_to_dict(self.proxy.ptr.metadata)
    
    def dump(self):
        lib.av_dump_format(self.proxy.ptr, 0, self.name, self.mode == 'w');


cdef class Stream(object):
    
    def __init__(self, Context ctx, int index):
        
        if index < 0 or index > ctx.proxy.ptr.nb_streams:
            raise ValueError('stream index out of range')
        
        self.ctx_proxy = ctx.proxy
        self.ptr = self.ctx_proxy.ptr.streams[index]
        
        if self.ptr.codec.codec_type == lib.AVMEDIA_TYPE_VIDEO:
            self.type = b'video'
        else:
            self.type = b'unknown'

        self.codec = av.codec.Codec(self)
        self.metadata = avdict_to_dict(self.ptr.metadata)
    
    def __repr__(self):
        return '<%s.%s #%d %s/%s at 0x%x>' % (
            self.__class__.__module__,
            self.__class__.__name__,
            self.index,
            self.type,
            self.codec.name,
            id(self),
        )
    
    property index:
        def __get__(self): return self.ptr.index
    property id:
        def __get__(self): return self.ptr.id
    property time_base:
        def __get__(self): return avrational_to_faction(&self.ptr.time_base)
    property base_frame_rate:
        def __get__(self): return avrational_to_faction(&self.ptr.r_frame_rate)
    property avg_frame_rate:
        def __get__(self): return avrational_to_faction(&self.ptr.avg_frame_rate)
    property start_time:
        def __get__(self): return self.ptr.start_time
    property duration:
        def __get__(self): return self.ptr.duration
    
        


# Handy alias.
open = Context
