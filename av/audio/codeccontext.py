import cython
from cython.cimports import libav as lib
from cython.cimports.av.audio.format import AudioFormat, get_audio_format
from cython.cimports.av.audio.frame import AudioFrame, alloc_audio_frame
from cython.cimports.av.audio.layout import AudioLayout, get_audio_layout
from cython.cimports.av.frame import Frame
from cython.cimports.av.packet import Packet


@cython.cclass
class AudioCodecContext(CodecContext):
    @cython.cfunc
    def _prepare_frames_for_encode(self, input_frame: Frame | None):
        frame: AudioFrame | None = input_frame
        allow_var_frame_size: cython.bint = (
            self.ptr.codec.capabilities & lib.AV_CODEC_CAP_VARIABLE_FRAME_SIZE
        )

        # Note that the resampler will simply return an input frame if there is
        # no resampling to be done. The control flow was just a little easier this way.
        if not self.resampler:
            self.resampler = AudioResampler(
                format=self.format,
                layout=self.layout,
                rate=self.ptr.sample_rate,
                frame_size=None if allow_var_frame_size else self.ptr.frame_size,
            )
        frames = self.resampler.resample(frame)
        if input_frame is None:
            frames.append(None)  # flush if input frame is None

        return frames

    @cython.cfunc
    def _alloc_next_frame(self) -> Frame:
        return alloc_audio_frame()

    @cython.cfunc
    def _setup_decoded_frame(self, frame: Frame, packet: Packet):
        CodecContext._setup_decoded_frame(self, frame, packet)
        aframe: AudioFrame = frame
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
    def sample_rate(self, value: cython.int):
        self.ptr.sample_rate = value

    @property
    def rate(self):
        """Another name for :attr:`sample_rate`."""
        return self.sample_rate

    @rate.setter
    def rate(self, value):
        self.sample_rate = value

    @property
    def channels(self):
        return self.layout.nb_channels

    @property
    def layout(self):
        """
        The audio channel layout.

        :type: AudioLayout
        """
        return get_audio_layout(self.ptr.ch_layout)

    @layout.setter
    def layout(self, value):
        layout: AudioLayout = AudioLayout(value)
        self.ptr.ch_layout = layout.layout

    @property
    def format(self):
        """
        The audio sample format.

        :type: AudioFormat
        """
        return get_audio_format(self.ptr.sample_fmt)

    @format.setter
    def format(self, value):
        format: AudioFormat = AudioFormat(value)
        self.ptr.sample_fmt = format.sample_fmt
