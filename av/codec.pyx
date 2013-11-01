from cpython.oldbuffer cimport PyBuffer_FromMemory
from cpython cimport array
from libc.stdint cimport int64_t, uint8_t, uint64_t

cimport libav as lib

from av.utils cimport err_check, avrational_to_faction,to_avrational, channel_layout_name,samples_alloc_array_and_samples
from av.context cimport ContextProxy
from av.stream cimport Stream


cdef class Codec(object):
    
    def __init__(self, Stream stream):
        
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
        if self.ptr != NULL:
            lib.avcodec_close(self.ctx);
        if self.options != NULL:
            lib.av_dict_free(&self.options)
    
    property name:
        def __get__(self): return bytes(self.ptr.name) if self.ptr else None
    property long_name:
        def __get__(self): return bytes(self.ptr.long_name) if self.ptr else None
        
    property bit_rate:
        def __get__(self): return self.ctx.bit_rate if self.ctx else None
        def __set__(self, int value):
            self.ctx.bit_rate = value
    property frame_rate:
        def __get__(self): return avrational_to_faction(&self.frame_rate_) if self.ctx else None
        def __set__(self,value): to_avrational(value, &self.frame_rate_)
            
    property bit_rate_tolerance:
        def __get__(self): return self.ctx.bit_rate_tolerance if self.ctx else None
        def __set__(self, int value):
            self.ctx.bit_rate_tolerance = value
            
    property time_base:
        def __get__(self): return avrational_to_faction(&self.ctx.time_base) if self.ctx else None
        def __set__(self,value): to_avrational(value, &self.ctx.time_base)
        
    property gop_size:
        def __get__(self): return self.ctx.gop_size if self.ctx else None
        def __set__(self, int value):
            self.ctx.gop_size = value
            
    property pix_fmt:
        def __get__(self):
            if not self.ctx:
                return None
            result = lib.av_get_pix_fmt_name(self.ctx.pix_fmt)
            if result == NULL:
                return None
            return result
        # Note should check if codec supports pix_fmt
        def __set__(self, char* value):
            cdef lib.AVPixelFormat pix_fmt = lib.av_get_pix_fmt(value)
            if pix_fmt == lib.AV_PIX_FMT_NONE:
                raise ValueError("invalid pix_fmt %s" % value)
            self.ctx.pix_fmt = pix_fmt
    
    property frame_size:
        """Number of samples per channel in an audio frame."""
        def __get__(self): return self.ctx.frame_size
        
    property sample_rate:
        """samples per second """
        def __get__(self): return self.ctx.sample_rate
        def __set__(self, int value): self.ctx.sample_rate = value

    property sample_fmt:
        """Audio sample format"""
        def __get__(self):
            if not self.ctx:
                return None
            result = lib.av_get_sample_fmt_name(self.ctx.sample_fmt)
            if result == NULL:
                return None
            return result
        # Note should check if codec supports sample_fmt
        def __set__(self, char* value):
            cdef lib.AVSampleFormat sample_fmt = lib.av_get_sample_fmt(value)
            if sample_fmt == lib.AV_SAMPLE_FMT_NONE:
                raise ValueError("invalid sample_fmt %s" % value)
            self.ctx.sample_fmt = sample_fmt
    
    property channels:
        """Number of audio channels"""
        def __get__(self):
            return self.ctx.channels
        def __set__(self, int value):
            
            self.ctx.channels = value
            # set channel layout to default layout for that many channels
            self.ctx.channel_layout = lib.av_get_default_channel_layout(value)
            
    property channel_layout:
        """Audio channel layout"""
        def __get__(self):
            result = channel_layout_name(self.ctx.channels, self.ctx.channel_layout)
            if result == NULL:
                return None
            return result
        
        def __set__(self, char* value):
            
            cdef uint64_t channel_layout = lib.av_get_channel_layout(value)
            
            if channel_layout == 0:
                raise ValueError("invalid channel layout %s" % value)
            
            self.ctx.channel_layout = channel_layout
            self.ctx.channels = lib.av_get_channel_layout_nb_channels(channel_layout)
            
    property width:
        def __get__(self): return self.ctx.width if self.ctx else None
        def __set__(self, int value):
            self.ctx.width = value
            
    property height:
        def __get__(self): return self.ctx.height if self.ctx else None
        def __set__(self, int value):
            self.ctx.height = value

    property sample_aspect_ratio:
        def __get__(self): return avrational_to_faction(&self.ctx.sample_aspect_ratio) if self.ctx else None
        def __set__(self,value): to_avrational(value, &self.ctx.sample_aspect_ratio)
            
    
    
