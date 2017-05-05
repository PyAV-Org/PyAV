from av.audio.format cimport get_audio_format
from av.audio.frame cimport alloc_audio_frame
from av.audio.layout cimport get_audio_layout
from av.container.core cimport Container
from av.frame cimport Frame
from av.packet cimport Packet
from av.utils cimport err_check


cdef class AudioStream(Stream):

    cdef _init(self, Container container, lib.AVStream *stream):
        Stream._init(self, container, stream)
        
        # Sometimes there isn't a layout set, but there are a number of
        # channels. Assume it is the default layout.
        self.layout = get_audio_layout(self._codec_context.channels, self._codec_context.channel_layout)
        if not self._codec_context.channel_layout:
            self._codec_context.channel_layout = self.layout.layout

        self.format = get_audio_format(self._codec_context.sample_fmt)
    
    def __repr__(self):
        return '<av.%s #%d %s at %dHz, %s, %s at 0x%x>' % (
            self.__class__.__name__,
            self.index,
            self.name,
            self.rate,
            self.layout.name,
            self.format.name,
            id(self),
        )
