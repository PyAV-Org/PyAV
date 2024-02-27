import warnings

cimport libav as lib
from libc.stdint cimport int64_t

from av.codec.context cimport CodecContext
from av.frame cimport Frame
from av.packet cimport Packet
from av.utils cimport avrational_to_fraction, to_avrational
from av.video.format cimport VideoFormat, get_pix_fmt, get_video_format
from av.video.frame cimport VideoFrame, alloc_video_frame
from av.video.reformatter cimport VideoReformatter

from av.deprecation import AVDeprecationWarning


cdef class VideoCodecContext(CodecContext):
    def __cinit__(self, *args, **kwargs):
        self.last_w = 0
        self.last_h = 0

    cdef _init(self, lib.AVCodecContext *ptr, const lib.AVCodec *codec):
        CodecContext._init(self, ptr, codec)  # TODO: Can this be `super`?
        self._build_format()
        self.encoded_frame_count = 0

    cdef _set_default_time_base(self):
        self.ptr.time_base.num = self.ptr.framerate.den or 1
        self.ptr.time_base.den = self.ptr.framerate.num or lib.AV_TIME_BASE

    cdef _prepare_frames_for_encode(self, Frame input):
        if not input:
            return [None]

        cdef VideoFrame vframe = input

        # Reformat if it doesn't match.
        if (
            vframe.format.pix_fmt != self._format.pix_fmt or
            vframe.width != self.ptr.width or
            vframe.height != self.ptr.height
        ):
            if not self.reformatter:
                self.reformatter = VideoReformatter()
            vframe = self.reformatter.reformat(
                vframe,
                self.ptr.width,
                self.ptr.height,
                self._format,
            )

        # There is no pts, so create one.
        if vframe.ptr.pts == lib.AV_NOPTS_VALUE:
            vframe.ptr.pts = <int64_t>self.encoded_frame_count

        self.encoded_frame_count += 1

        return [vframe]

    cdef Frame _alloc_next_frame(self):
        return alloc_video_frame()

    cdef _setup_decoded_frame(self, Frame frame, Packet packet):
        CodecContext._setup_decoded_frame(self, frame, packet)
        cdef VideoFrame vframe = frame
        vframe._init_user_attributes()

    cdef _build_format(self):
        self._format = get_video_format(<lib.AVPixelFormat>self.ptr.pix_fmt, self.ptr.width, self.ptr.height)

    @property
    def format(self):
        return self._format

    @format.setter
    def format(self, VideoFormat format):
        self.ptr.pix_fmt = format.pix_fmt
        self.ptr.width = format.width
        self.ptr.height = format.height
        self._build_format()  # Kinda wasteful.

    @property
    def width(self):
        return self.ptr.width

    @width.setter
    def width(self, unsigned int value):
        self.ptr.width = value
        self._build_format()

    @property
    def height(self):
        return self.ptr.height

    @height.setter
    def height(self, unsigned int value):
        self.ptr.height = value
        self._build_format()

    @property
    def pix_fmt(self):
        """
        The pixel format's name.

        :type: str
        """
        return self._format.name

    @pix_fmt.setter
    def pix_fmt(self, value):
        self.ptr.pix_fmt = get_pix_fmt(value)
        self._build_format()

    @property
    def framerate(self):
        """
        The frame rate, in frames per second.

        :type: fractions.Fraction
        """
        return avrational_to_fraction(&self.ptr.framerate)

    @framerate.setter
    def framerate(self, value):
        to_avrational(value, &self.ptr.framerate)

    @property
    def rate(self):
        """Another name for :attr:`framerate`."""
        return self.framerate

    @rate.setter
    def rate(self, value):
        self.framerate = value

    @property
    def gop_size(self):
        """
        Sets the number of frames between keyframes. Used only for encoding.
        
        :type: int
        """
        if self.is_decoder:
            warnings.warn(
                "Using VideoCodecContext.gop_size for decoders is deprecated.",
                AVDeprecationWarning
            )
        return self.ptr.gop_size

    @gop_size.setter
    def gop_size(self, int value):
        if self.is_decoder:
            warnings.warn(
                "Using VideoCodecContext.gop_size for decoders is deprecated.",
                AVDeprecationWarning
            )
        self.ptr.gop_size = value

    @property
    def sample_aspect_ratio(self):
        return avrational_to_fraction(&self.ptr.sample_aspect_ratio)

    @sample_aspect_ratio.setter
    def sample_aspect_ratio(self, value):
        to_avrational(value, &self.ptr.sample_aspect_ratio)

    @property
    def display_aspect_ratio(self):
        cdef lib.AVRational dar

        lib.av_reduce(
            &dar.num, &dar.den,
            self.ptr.width * self.ptr.sample_aspect_ratio.num,
            self.ptr.height * self.ptr.sample_aspect_ratio.den, 1024*1024)

        return avrational_to_fraction(&dar)

    @property
    def has_b_frames(self):
        return bool(self.ptr.has_b_frames)

    @property
    def coded_width(self):
        return self.ptr.coded_width

    @property
    def coded_height(self):
        return self.ptr.coded_height

    @property
    def color_range(self):
        """
        Color range of context.

        Wraps :ffmpeg:`AVFrame.color_range`.
        """
        return self.ptr.color_range

    @color_range.setter
    def color_range(self, value):
        self.ptr.color_range = value

    @property
    def max_b_frames(self):
        """
        The maximum run of consecutive B frames when encoding a video.

        :type: int
        """
        return self.ptr.max_b_frames

    @max_b_frames.setter
    def max_b_frames(self, value):
        self.ptr.max_b_frames = value
