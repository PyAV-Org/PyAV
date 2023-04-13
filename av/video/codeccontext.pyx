cimport libav as lib
from libc.stdint cimport int64_t

from av.codec.context cimport CodecContext
from av.frame cimport Frame
from av.packet cimport Packet
from av.utils cimport avrational_to_fraction, to_avrational
from av.video.format cimport VideoFormat, get_pix_fmt, get_video_format
from av.video.frame cimport VideoFrame, alloc_video_frame
from av.video.reformatter cimport VideoReformatter


cdef class VideoCodecContext(CodecContext):
    def __cinit__(self, *args, **kwargs):
        self.last_w = 0
        self.last_h = 0

    cdef _init(self, lib.AVCodecContext *ptr, const lib.AVCodec *codec):
        CodecContext._init(self, ptr, codec)  # TODO: Can this be `super`?
        self._build_format()
        self.encoded_frame_count = 0

    cdef _prepare_frames_for_encode(self, Frame input):
        if not input:
            return [None]

        cdef VideoFrame vframe = input

        if self._format is None:
            raise ValueError("self._format is None, cannot encode")

        # Reformat if it doesn't match.
        if (
            vframe.format.pix_fmt != self._format.pix_fmt or
            vframe.width != self.ptr.width or
            vframe.height != self.ptr.height
        ):
            if not self.reformatter:
                self.reformatter = VideoReformatter()

            vframe = self.reformatter.reformat(
                vframe, self.ptr.width, self.ptr.height, self._format
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
        if self.ptr is NULL:
            return 0
        return self.ptr.width

    @width.setter
    def width(self, unsigned int value):
        self.ptr.width = value
        self._build_format()

    @property
    def height(self):
        if self.ptr is NULL:
            return 0
        return self.ptr.height

    @height.setter
    def height(self, unsigned int value):
        self.ptr.height = value
        self._build_format()

    @property
    def bits_per_coded_sample(self):
        """
        The number of bits per sample in the codedwords. It's mandatory for this to be set for some formats to decode properly.

        Wraps :ffmpeg:`AVCodecContext.bits_per_coded_sample`.
        
        :type: int
        """
        return self.ptr.bits_per_coded_sample
      
    @bits_per_coded_sample.setter
    def bits_per_coded_sample(self, int value):
        if self.is_encoder:
            raise ValueError("Not supported for encoders")

        self.ptr.bits_per_coded_sample = value
        self._build_format()

    @property
    def pix_fmt(self):
        """
        The pixel format's name.

        :type: str | None
        """
        return getattr(self._format, "name", None)

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
            raise RuntimeError("Cannnot access 'gop_size' as a decoder")
        return self.ptr.gop_size

    @gop_size.setter
    def gop_size(self, int value):
        if self.is_decoder:
            raise RuntimeError("Cannnot access 'gop_size' as a decoder")
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
        """
        :type: bool
        """
        return bool(self.ptr.has_b_frames)

    @property
    def coded_width(self):
        """
        :type: int
        """
        return self.ptr.coded_width

    @property
    def coded_height(self):
        """
        :type: int
        """
        return self.ptr.coded_height

    @property
    def color_range(self):
        """
        Describes the signal range of the colorspace.

        Wraps :ffmpeg:`AVFrame.color_range`.

        :type: int
        """
        return self.ptr.color_range

    @color_range.setter
    def color_range(self, value):
        self.ptr.color_range = value

    @property
    def color_primaries(self):
        """
        Describes the RGB/XYZ matrix of the colorspace.

        Wraps :ffmpeg:`AVFrame.color_primaries`.

        :type: int
        """
        return self.ptr.color_primaries

    @color_primaries.setter
    def color_primaries(self, value):
        self.ptr.color_primaries = value

    @property
    def color_trc(self):
        """
        Describes the linearization function (a.k.a. transformation characteristics) of the colorspace.

        Wraps :ffmpeg:`AVFrame.color_trc`.

        :type: int
        """
        return self.ptr.color_trc

    @color_trc.setter
    def color_trc(self, value):
        self.ptr.color_trc = value

    @property
    def colorspace(self):
        """
        Describes the YUV/RGB transformation matrix of the colorspace.

        Wraps :ffmpeg:`AVFrame.colorspace`.

        :type: int
        """
        return self.ptr.colorspace

    @colorspace.setter
    def colorspace(self, value):
        self.ptr.colorspace = value

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

    @property
    def qmin(self):
        """
        The minimum quantiser value of an encoded stream.

        Wraps :ffmpeg:`AVCodecContext.qmin`.

        :type: int
        """
        return self.ptr.qmin

    @qmin.setter
    def qmin(self, value):
        self.ptr.qmin = value

    @property
    def qmax(self):
        """
        The maximum quantiser value of an encoded stream.

        Wraps :ffmpeg:`AVCodecContext.qmax`.

        :type: int
        """
        return self.ptr.qmax

    @qmax.setter
    def qmax(self, value):
        self.ptr.qmax = value
