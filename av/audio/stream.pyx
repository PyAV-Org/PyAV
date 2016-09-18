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

    property frame_size:
        """Number of samples per channel in an audio frame."""
        def __get__(self): return self._codec_context.frame_size
        
    property rate:
        """samples per second """
        def __get__(self): return self._codec_context.sample_rate
        def __set__(self, int value): self._codec_context.sample_rate = value

    property channels:
        def __get__(self):
            return self._codec_context.channels

    def encode(self, AudioFrame input_frame=None):
        """Encodes a frame of audio, returns a packet if one is ready.
        The output packet does not necessarily contain data for the most recent frame, 
        as encoders can delay, split, and combine input frames internally as needed.
        If called with with no args it will flush out the encoder and return the buffered
        packets until there are none left, at which it will return None.
        """

        self._weak_container().start_encoding()
        if not self.resampler:
            self.resampler = AudioResampler(
                self.format,
                self.layout,
                self._codec_context.sample_rate)

        cdef AudioFrame resampled_frame
        if input_frame:
            resampled_frame = self.resampler.resample(input_frame)
        else:
            resampled_frame = input_frame

        if resampled_frame:

            # If the resampled_frame has a valid pts, scale it to the codec's time_base.
            # Remember that the AudioFifo time_base is always 1/sample_rate!
            if resampled_frame.ptr.pts != lib.AV_NOPTS_VALUE:
                resampled_frame.ptr.pts = lib.av_rescale_q(
                    resampled_frame.ptr.pts,
                    resampled_frame._time_base,
                    self._codec_context.time_base)
            else:
                resampled_frame.ptr.pts = lib.av_rescale(
                    self._codec_context.frame_number,
                    self._codec_context.sample_rate,
                    self._codec_context.frame_size)

        cdef Packet packet
        for packet in self.coder.encode(resampled_frame):
            # Rescale some times which are in the codec's time_base to the
            # stream's time_base.
            if packet.struct.pts != lib.AV_NOPTS_VALUE:
                packet.struct.pts = lib.av_rescale_q(
                    packet.struct.pts,
                    self._codec_context.time_base,
                    self._stream.time_base
                )
            if packet.struct.dts != lib.AV_NOPTS_VALUE:
                packet.struct.dts = lib.av_rescale_q(
                    packet.struct.dts,
                    self._codec_context.time_base,
                    self._stream.time_base
                )
            if packet.struct.duration > 0:
                packet.struct.duration = lib.av_rescale_q(
                    packet.struct.duration,
                    self._codec_context.time_base,
                    self._stream.time_base
                )

            # `coded_frame` is "the picture in the bitstream"; does this make
            # sense for audio?
            if self._codec_context.coded_frame:
                if self._codec_context.coded_frame.key_frame:
                    packet.struct.flags |= lib.AV_PKT_FLAG_KEY

            packet.struct.stream_index = self._stream.index
            packet.stream = self

            yield packet
