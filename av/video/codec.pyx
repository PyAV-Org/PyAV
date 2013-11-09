cimport libav as lib

from av.utils cimport avrational_to_faction, to_avrational
from av.stream cimport Stream
from av.video.format cimport blank_video_format


cdef class VideoCodec(Codec):
    
    def __cinit__(self, Stream stream):
        
        if not self.ctx:
            return

        # Build the VideoFormat.
        self.format = blank_video_format()
        self.format._init(<lib.AVPixelFormat>self.ctx.pix_fmt, self.ctx.width, self.ctx.height)

    def __repr__(self):
        return '<av.%s %s, %s %dx%d at 0x%x>' % (
            self.__class__.__name__,
            self.name,
            self.format.name,
            self.format.width,
            self.format.height,
            id(self),
        )

    property frame_rate:
        def __get__(self):
            return avrational_to_faction(&self.frame_rate_) if self.ctx else None
        def __set__(self, value):
            to_avrational(value, &self.frame_rate_)

    property gop_size:
        def __get__(self):
            return self.ctx.gop_size if self.ctx else None
        def __set__(self, int value):
            self.ctx.gop_size = value

    property sample_aspect_ratio:
        def __get__(self):
            return avrational_to_faction(&self.ctx.sample_aspect_ratio) if self.ctx else None
        def __set__(self, value):
            to_avrational(value, &self.ctx.sample_aspect_ratio)
