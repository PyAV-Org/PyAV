from libc.stdint cimport int64_t
cimport libav as lib

from av.codec.context cimport CodecContext
from av.error cimport err_check
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

    property format:
        def __get__(self):
            return self._format

        def __set__(self, VideoFormat format):
            self.ptr.pix_fmt = format.pix_fmt
            self.ptr.width = format.width
            self.ptr.height = format.height
            self._build_format()  # Kinda wasteful.

    property width:
        def __get__(self):
            return self.ptr.width

        def __set__(self, unsigned int value):
            self.ptr.width = value
            self._build_format()

    property height:
        def __get__(self):
            return self.ptr.height

        def __set__(self, unsigned int value):
            self.ptr.height = value
            self._build_format()

    property pix_fmt:
        """
        The pixel format's name.

        :type: str
        """
        def __get__(self):
            return self._format.name

        def __set__(self, value):
            self.ptr.pix_fmt = get_pix_fmt(value)
            self._build_format()

    property framerate:
        """
        The frame rate, in frames per second.

        :type: fractions.Fraction
        """
        def __get__(self):
            return avrational_to_fraction(&self.ptr.framerate)

        def __set__(self, value):
            to_avrational(value, &self.ptr.framerate)

    property rate:
        """Another name for :attr:`framerate`."""
        def __get__(self):
            return self.framerate

        def __set__(self, value):
            self.framerate = value

    property gop_size:
        def __get__(self):
            return self.ptr.gop_size

        def __set__(self, int value):
            self.ptr.gop_size = value

    property sample_aspect_ratio:
        def __get__(self):
            return avrational_to_fraction(&self.ptr.sample_aspect_ratio)

        def __set__(self, value):
            to_avrational(value, &self.ptr.sample_aspect_ratio)

    property display_aspect_ratio:
        def __get__(self):
            cdef lib.AVRational dar

            lib.av_reduce(
                &dar.num, &dar.den,
                self.ptr.width * self.ptr.sample_aspect_ratio.num,
                self.ptr.height * self.ptr.sample_aspect_ratio.den, 1024*1024)

            return avrational_to_fraction(&dar)

    property has_b_frames:
        def __get__(self):
            return bool(self.ptr.has_b_frames)

    property coded_width:
        def __get__(self):
            return self.ptr.coded_width

    property coded_height:
        def __get__(self):
            return self.ptr.coded_height
