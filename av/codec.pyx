cimport libav as lib

cimport av.format


cdef class Codec(object):
    
    def __init__(self, av.format.Stream stream):
        
        # Our pointer.
        self.ctx = stream.ptr.codec
        
        # Keep these pointer alive with this reference.
        self.format_ctx = stream.ctx_proxy
        
        # We don't need to free this later since it is a static part of the lib.
        self.ptr = lib.avcodec_find_decoder(self.ctx.codec_id)
    
    @property
    def name(self):
        return bytes(self.ptr.name)
    
    @property
    def long_name(self):
        return bytes(self.ptr.long_name)
    
    