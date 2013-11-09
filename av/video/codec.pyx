cimport libav as lib

from av.utils cimport avrational_to_faction, to_avrational


cdef class VideoCodec(Codec):
    
    property frame_rate:
        def __get__(self): return avrational_to_faction(&self.frame_rate_) if self.ctx else None
        def __set__(self,value): to_avrational(value, &self.frame_rate_)

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
