cimport libav as lib

cimport av.format


cdef class Codec(object):
    
    def __cinit__(self, av.format.Stream stream):
        self.format_ctx = stream.ctx_proxy
        self.ctx = stream.ptr.codec
        self.ptr = lib.avcodec_find_decoder(self.ctx.codec_id)
    
    @property
    def name(self):
        return bytes(self.ptr.name)
    
    @property
    def long_name(self):
        return bytes(self.ptr.long_name)
    
    