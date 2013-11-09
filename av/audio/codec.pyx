cimport libav as lib

from av.audio.layout cimport get_audio_layout
from av.audio.format cimport get_audio_format
from av.stream cimport Stream


cdef class AudioCodec(Codec):

    def __cinit__(self, Stream stream):
        if not self.ctx:
            return
        self.layout = get_audio_layout(self.ctx.channel_layout)
        self.format = get_audio_format(self.ctx.sample_fmt)

    def __repr__(self):
        return '<av.%s %s at %dHz, %s, %s at 0x%x>' % (
            self.__class__.__name__,
            self.name,
            self.rate,
            self.layout.name,
            self.format.name,
            id(self),
        )

    property frame_size:
        """Number of samples per channel in an audio frame."""
        def __get__(self): return self.ctx.frame_size
        
    property rate:
        """samples per second """
        def __get__(self): return self.ctx.sample_rate
        def __set__(self, int value): self.ctx.sample_rate = value
