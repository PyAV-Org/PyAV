import cython
import cython.cimports.libav as lib
from cython.cimports.av.codec.context import CodecContext
from cython.cimports.av.codec.hwaccel import HWAccel
from cython.cimports.av.error import err_check
from cython.cimports.av.frame import Frame
from cython.cimports.av.packet import Packet
from cython.cimports.av.utils import avrational_to_fraction, to_avrational
from cython.cimports.av.video.format import VideoFormat, get_pix_fmt, get_video_format
from cython.cimports.av.video.frame import VideoFrame, alloc_video_frame
from cython.cimports.av.video.reformatter import VideoReformatter
from cython.cimports.libc.stdint import int64_t


@cython.cfunc
@cython.exceptval(check=False)
def _get_hw_format(
    ctx: cython.pointer[lib.AVCodecContext],
    pix_fmts: cython.pointer[cython.const[lib.AVPixelFormat]],
) -> lib.AVPixelFormat:
    # In the case where we requested accelerated decoding, the decoder first calls this function
    # with a list that includes both the hardware format and software formats.
    # First we try to pick the hardware format if it's in the list.
    # However, if the decoder fails to initialize the hardware, it will call this function again,
    # with only software formats in pix_fmts. We return ctx->sw_pix_fmt regardless in this case,
    # because that should be in the candidate list. If not, we are out of ideas anyways.
    private_data: cython.pointer[AVCodecPrivateData] = cython.cast(
        cython.pointer[AVCodecPrivateData], ctx.opaque
    )
    i: cython.int = 0
    while pix_fmts[i] != -1:
        if pix_fmts[i] == private_data.hardware_pix_fmt:
            return pix_fmts[i]
        i += 1
    return (
        ctx.sw_pix_fmt if private_data.allow_software_fallback else lib.AV_PIX_FMT_NONE
    )


@cython.cclass
class VideoCodecContext(CodecContext):
    def __cinit__(self, *args, **kwargs):
        self.last_w = 0
        self.last_h = 0

    @cython.cfunc
    def _init(
        self,
        ptr: cython.pointer[lib.AVCodecContext],
        codec: cython.pointer[cython.const[lib.AVCodec]],
        hwaccel: HWAccel | None,
    ):
        CodecContext._init(self, ptr, codec, hwaccel)

        if hwaccel is not None:
            try:
                self.hwaccel_ctx = hwaccel.create(self.codec)
                self.ptr.hw_device_ctx = lib.av_buffer_ref(self.hwaccel_ctx.ptr)
                self.ptr.pix_fmt = self.hwaccel_ctx.config.ptr.pix_fmt
                self.ptr.get_format = _get_hw_format
                self._private_data.hardware_pix_fmt = (
                    self.hwaccel_ctx.config.ptr.pix_fmt
                )
                self._private_data.allow_software_fallback = (
                    self.hwaccel.allow_software_fallback
                )
                self.ptr.opaque = cython.address(self._private_data)
            except NotImplementedError:
                # Some streams may not have a hardware decoder. For example, many action
                # cam videos have a low resolution mjpeg stream, which is usually not
                # compatible with hardware decoders.
                # The user may have passed in a hwaccel because they want to decode the main
                # stream with it, so we shouldn't abort even if we find a stream that can't
                # be HW decoded.
                # If the user wants to make sure hwaccel is actually used, they can check with the
                # is_hwaccel() function on each stream's codec context.
                self.hwaccel_ctx = None

        self._build_format()
        self.encoded_frame_count = 0

    @cython.cfunc
    def _prepare_frames_for_encode(self, input: Frame | None) -> list:
        if input is None or not input:
            return [None]

        if self._format is None:
            raise ValueError("self._format is None, cannot encode")

        vframe: VideoFrame = input
        # Reformat if it doesn't match.
        if (
            vframe.format.pix_fmt != self._format.pix_fmt
            or vframe.width != self.ptr.width
            or vframe.height != self.ptr.height
        ):
            if not self.reformatter:
                self.reformatter = VideoReformatter()

            vframe = self.reformatter.reformat(
                vframe, self.ptr.width, self.ptr.height, self._format
            )

        # There is no pts, so create one.
        if vframe.ptr.pts == lib.AV_NOPTS_VALUE:
            vframe.ptr.pts = cython.cast(int64_t, self.encoded_frame_count)

        self.encoded_frame_count += 1
        return [vframe]

    @cython.cfunc
    def _alloc_next_frame(self) -> Frame:
        return alloc_video_frame()

    @cython.cfunc
    def _setup_decoded_frame(self, frame: Frame, packet: Packet):
        CodecContext._setup_decoded_frame(self, frame, packet)
        vframe: VideoFrame = frame
        vframe._init_user_attributes()

    @cython.cfunc
    def _transfer_hwframe(self, frame: Frame):
        if self.hwaccel_ctx is None:
            return frame
        if frame.ptr.format != self.hwaccel_ctx.config.ptr.pix_fmt:
            # If we get a software frame, that means we are in software fallback mode, and don't actually
            # need to transfer.
            return frame

        if self.hwaccel_ctx.is_hw_owned:
            cython.cast(VideoFrame, frame)._device_id = self.hwaccel_ctx.device_id
            return frame

        frame_sw: Frame = self._alloc_next_frame()
        err_check(lib.av_hwframe_transfer_data(frame_sw.ptr, frame.ptr, 0))
        # TODO: Is there anything else to transfer?
        frame_sw.pts = frame.pts
        return frame_sw

    @cython.cfunc
    def _build_format(self):
        self._format = get_video_format(
            cython.cast(lib.AVPixelFormat, self.ptr.pix_fmt),
            self.ptr.width,
            self.ptr.height,
        )

    @property
    def format(self):
        return self._format

    @format.setter
    def format(self, format: VideoFormat):
        self.ptr.pix_fmt = format.pix_fmt
        self.ptr.width = format.width
        self.ptr.height = format.height
        self._build_format()  # Kinda wasteful.

    @property
    def width(self):
        if self.ptr is cython.NULL:
            return 0
        return self.ptr.width

    @width.setter
    def width(self, value: cython.uint):
        self.ptr.width = value
        self._build_format()

    @property
    def height(self):
        if self.ptr is cython.NULL:
            return 0
        return self.ptr.height

    @height.setter
    def height(self, value: cython.uint):
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
    def bits_per_coded_sample(self, value: cython.int):
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
        return avrational_to_fraction(cython.address(self.ptr.framerate))

    @framerate.setter
    def framerate(self, value):
        to_avrational(value, cython.address(self.ptr.framerate))

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
            raise RuntimeError("Cannot access 'gop_size' as a decoder")
        return self.ptr.gop_size

    @gop_size.setter
    def gop_size(self, value: cython.int):
        if self.is_decoder:
            raise RuntimeError("Cannot access 'gop_size' as a decoder")
        self.ptr.gop_size = value

    @property
    def sample_aspect_ratio(self):
        return avrational_to_fraction(cython.address(self.ptr.sample_aspect_ratio))

    @sample_aspect_ratio.setter
    def sample_aspect_ratio(self, value):
        to_avrational(value, cython.address(self.ptr.sample_aspect_ratio))

    @property
    def display_aspect_ratio(self):
        dar: lib.AVRational
        lib.av_reduce(
            cython.address(dar.num),
            cython.address(dar.den),
            self.ptr.width * self.ptr.sample_aspect_ratio.num,
            self.ptr.height * self.ptr.sample_aspect_ratio.den,
            1024 * 1024,
        )

        return avrational_to_fraction(cython.address(dar))

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
