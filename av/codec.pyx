from cpython.oldbuffer cimport PyBuffer_FromMemory
from cpython cimport array
from libc.stdint cimport int64_t, uint8_t, uint64_t

cimport libav as lib

from av.audio.codec cimport AudioCodec
from av.context cimport ContextProxy
from av.stream cimport Stream
from av.utils cimport err_check, avrational_to_faction, to_avrational
from av.video.codec cimport VideoCodec


cdef Codec codec_factory(Stream stream):
    cdef lib.AVCodecContext *ptr = stream.ptr.codec
    if ptr.codec_type == lib.AVMEDIA_TYPE_VIDEO:
        return VideoCodec(stream)
    elif ptr.codec_type == lib.AVMEDIA_TYPE_AUDIO:
        return AudioCodec(stream)
    else:
        return Codec(stream)


cdef class Codec(object):
    
    def __cinit__(self, Stream stream):
        
        # Our pointer.
        self.ctx = stream.ptr.codec
        
        # Keep these pointer alive with this reference.
        self.format_ctx = stream.ctx
        
        if stream.type == 'attachment':
            return
        
        if self.format_ctx.is_input:
            # Find the decoder.
            # We don't need to free this later since it is a static part of the lib.
            self.ptr = lib.avcodec_find_decoder(self.ctx.codec_id)
            if self.ptr == NULL:
                return
            
            # Open the codec.
            try:
                err_check(lib.avcodec_open2(self.ctx, self.ptr, &self.options))
            except:
                # Signal that we don't need to close it.
                self.ptr = NULL
                raise
        
        else:
            self.ptr = self.ctx.codec
    
    def __dealloc__(self):
        if self.ptr:
            lib.avcodec_close(self.ctx);
        if self.options:
            lib.av_dict_free(&self.options)
    
    def __repr__(self):
        return '<av.%s %s>' % (self.__class__.__name__, self.name)

    property name:
        def __get__(self):
            return bytes(self.ptr.name) if self.ptr else None

    property long_name:
        def __get__(self):
            return bytes(self.ptr.long_name) if self.ptr else None
        
    property bit_rate:
        def __get__(self):
            return self.ctx.bit_rate if self.ctx else None
        def __set__(self, int value):
            self.ctx.bit_rate = value
            
    property bit_rate_tolerance:
        def __get__(self):
            return self.ctx.bit_rate_tolerance if self.ctx else None
        def __set__(self, int value):
            self.ctx.bit_rate_tolerance = value
            
    property time_base:
        def __get__(self): 
            return avrational_to_faction(&self.ctx.time_base) if self.ctx else None
        def __set__(self, value):
            to_avrational(value, &self.ctx.time_base)
        
