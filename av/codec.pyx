cimport libav as lib

cimport av.format
from .utils cimport err_check

cdef class Codec(object):
    
    def __init__(self, av.format.Stream stream):
        
        
        # Our pointer.
        self.ctx = stream.ptr.codec
        
        # Keep these pointer alive with this reference.
        self.format_ctx = stream.ctx_proxy
        
        # We don't need to free this later since it is a static part of the lib.
        self.ptr = lib.avcodec_find_decoder(self.ctx.codec_id)
        
        # "Open" the codec.
        # TODO: Do we have to deallocate this?
        cdef lib.AVDictionary *options = NULL
        try:
            err_check(lib.avcodec_open2(self.ctx, self.ptr, &options))
        except:
            self.ptr = NULL
            raise
    
    def __dealloc__(self):
        if self.ptr != NULL:
            lib.avcodec_close(self.ctx);
    
    property name:
        def __get__(self): return bytes(self.ptr.name)
    property long_name:
        def __get__(self): return bytes(self.ptr.long_name)
    

cdef class Packet(object):
    
    def __dealloc__(self):
        lib.av_free_packet(&self.packet)
    
    def __repr__(self):
        return '<%s.%s of %s at 0x%x>' % (
            self.__class__.__module__,
            self.__class__.__name__,
            self.stream,
            id(self),
        )
    
    property pts:
        def __get__(self): return self.packet.pts
    property dts:
        def __get__(self): return self.packet.dts
    property size:
        def __get__(self): return self.packet.size
    property duration:
        def __get__(self): return self.packet.duration