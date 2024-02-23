cimport libav as lib

from av.audio.format cimport AudioFormat, get_audio_format
from av.audio.frame cimport AudioFrame, alloc_audio_frame
from av.audio.layout cimport AudioLayout, get_audio_layout
from av.frame cimport Frame
from av.packet cimport Packet


cdef class AudioCodecContext(CodecContext):
    cdef _init(self, lib.AVCodecContext *ptr, const lib.AVCodec *codec):
        CodecContext._init(self, ptr, codec)

        # Sometimes there isn't a layout set, but there are a number of
        # channels. Assume it is the default layout.
        # TODO: Put this behind `not bare_metal`.
        # TODO: Do this more efficiently.
        if self.ptr.channels and not self.ptr.channel_layout:
            self.ptr.channel_layout = get_audio_layout(self.ptr.channels, 0).layout

    cdef _set_default_time_base(self):
        self.ptr.time_base.num = 1
        self.ptr.time_base.den = self.ptr.sample_rate

    cdef _prepare_frames_for_encode(self, Frame input_frame):

        cdef AudioFrame frame = input_frame

        cdef bint allow_var_frame_size = self.ptr.codec.capabilities & lib.AV_CODEC_CAP_VARIABLE_FRAME_SIZE

        # Note that the resampler will simply return an input frame if there is
        # no resampling to be done. The control flow was just a little easier this way.
        if not self.resampler:
            self.resampler = AudioResampler(
                format=self.format,
                layout=self.layout,
                rate=self.ptr.sample_rate,
                frame_size=None if allow_var_frame_size else self.ptr.frame_size
            )
        frames = self.resampler.resample(frame)

        # flush if input frame is None
        if input_frame is None:
            frames.append(None)

        return frames

    cdef Frame _alloc_next_frame(self):
        return alloc_audio_frame()

    cdef _setup_decoded_frame(self, Frame frame, Packet packet):
        CodecContext._setup_decoded_frame(self, frame, packet)
        cdef AudioFrame aframe = frame
        aframe._init_user_attributes()

    @property
    def frame_size(self):
        """
        Number of samples per channel in an audio frame.

        :type: int
        """
        return self.ptr.frame_size


    @property
    def sample_rate(self):
        """
        Sample rate of the audio data, in samples per second.

        :type: int
        """
        return self.ptr.sample_rate

    @sample_rate.setter
    def sample_rate(self, int value):
        self.ptr.sample_rate = value

    @property
    def rate(self):
        """Another name for :attr:`sample_rate`."""
        return self.sample_rate

    @rate.setter
    def rate(self, value):
        self.sample_rate = value

    # TODO: Integrate into AudioLayout.
    @property
    def channels(self):
        return self.ptr.channels

    @channels.setter
    def channels(self, value):
        self.ptr.channels = value
        self.ptr.channel_layout = lib.av_get_default_channel_layout(value)
    @property
    def channel_layout(self):
        return self.ptr.channel_layout

    @property
    def layout(self):
        """
        The audio channel layout.

        :type: AudioLayout
        """
        return get_audio_layout(self.ptr.channels, self.ptr.channel_layout)

    @layout.setter
    def layout(self, value):
        cdef AudioLayout layout = AudioLayout(value)
        self.ptr.channel_layout = layout.layout
        self.ptr.channels = layout.nb_channels

    @property
    def format(self):
        """
        The audio sample format.

        :type: AudioFormat
        """
        return get_audio_format(self.ptr.sample_fmt)

    @format.setter
    def format(self, value):
        cdef AudioFormat format = AudioFormat(value)
        self.ptr.sample_fmt = format.sample_fmt
