import cython
from cython.cimports import libav as lib
from cython.cimports.av.packet import Packet
from cython.cimports.av.stream import Stream
from cython.cimports.av.utils import avrational_to_fraction
from cython.cimports.av.video.frame import VideoFrame
from cython.cimports.libc.stdint import int32_t
from cython.cimports.libc.string import memcpy


@cython.final
@cython.cclass
class VideoStream(Stream):
    def __repr__(self):
        if self.codec_context is None:
            return f"<av.VideoStream #{self.index} video/<nocodec> at 0x{id(self):x}>"
        return (
            f"<av.VideoStream #{self.index} {self.name}, "
            f"{self.format.name if self.format else None} {self.codec_context.width}x"
            f"{self.codec_context.height} at 0x{id(self):x}>"
        )

    def __getattr__(self, name):
        if name in ("framerate", "rate"):
            raise AttributeError(
                f"'{type(self).__name__}' object has no attribute '{name}'"
            )
        if self.codec_context is None:
            raise AttributeError(
                f"'{type(self).__name__}' object has no attribute '{name}'"
            )
        return getattr(self.codec_context, name)

    @cython.ccall
    def encode(self, frame: VideoFrame | None = None):
        """
        Encode an :class:`.VideoFrame` and return a list of :class:`.Packet`.

        :rtype: list[Packet]

        .. seealso:: This is mostly a passthrough to :meth:`.CodecContext.encode`.
        """

        packets = self.codec_context.encode(frame)
        packet: Packet
        for packet in packets:
            packet._stream = self
            packet.ptr.stream_index = self.ptr.index
        return packets

    @cython.ccall
    def decode(self, packet: Packet | None = None):
        """
        Decode a :class:`.Packet` and return a list of :class:`.VideoFrame`.

        :rtype: list[VideoFrame]

        .. seealso:: This is a passthrough to :meth:`.CodecContext.decode`.
        """
        return self.codec_context.decode(packet)

    @cython.cfunc
    def _finalize_for_output(self):
        Stream._finalize_for_output(self)
        # avcodec_parameters_from_context() overwrites codecpar.coded_side_data,
        # so inject the display matrix after it, before avformat_write_header().
        if self.codec_context is not None and self._has_display_matrix:
            self._apply_display_matrix()

    @cython.cfunc
    def _apply_display_matrix(self):
        n: cython.int = 9 * cython.sizeof(int32_t)
        sd: cython.pointer[lib.AVPacketSideData] = lib.av_packet_side_data_new(
            cython.address(self.ptr.codecpar.coded_side_data),
            cython.address(self.ptr.codecpar.nb_coded_side_data),
            lib.AV_PKT_DATA_DISPLAYMATRIX,
            n,
            0,
        )
        if sd == cython.NULL:
            raise MemoryError("could not allocate display matrix side data")

        memcpy(sd.data, self._display_matrix, n)

    def set_display_matrix(self, matrix):
        """Set the display matrix written to the container as coded side data.

        ``matrix`` is a sequence of 9 integers in FFmpeg's ``AV_PKT_DATA_DISPLAYMATRIX``
        layout, or ``None`` to clear. Must be called before the first frame is
        encoded. See :meth:`set_display_rotation` for a higher-level helper.
        """
        if matrix is None:
            self._has_display_matrix = False
            return

        vals = [int(v) for v in matrix]
        if len(vals) != 9:
            raise ValueError("display matrix must have exactly 9 elements")
        i: cython.int
        for i in range(9):
            self._display_matrix[i] = vals[i]
        self._has_display_matrix = True

    def set_display_rotation(self, degrees, hflip=False, vflip=False):
        """Set the container display matrix from a rotation and optional flips.

        ``degrees`` is a counter-clockwise rotation (matching the value read back
        from :attr:`VideoFrame.rotation`); ``hflip`` / ``vflip`` mirror after it.
        Together these express all eight EXIF orientations. Must be called before
        the first frame is encoded.
        """
        # av_display_rotation_set() takes a clockwise angle; negate so our public
        # `degrees` is counter-clockwise, matching VideoFrame.rotation on read.
        lib.av_display_rotation_set(self._display_matrix, -float(degrees))
        lib.av_display_matrix_flip(self._display_matrix, bool(hflip), bool(vflip))
        self._has_display_matrix = True

    @property
    def average_rate(self):
        """
        The average frame rate of this video stream.

        This is calculated when the file is opened by looking at the first
        few frames and averaging their rate.

        :type: fractions.Fraction | None
        """
        return avrational_to_fraction(cython.address(self.ptr.avg_frame_rate))

    @property
    def base_rate(self):
        """
        The base frame rate of this stream.

        This is calculated as the lowest framerate at which the timestamps of
        frames can be represented accurately. See :ffmpeg:`AVStream.r_frame_rate`
        for more.

        :type: fractions.Fraction | None
        """
        return avrational_to_fraction(cython.address(self.ptr.r_frame_rate))

    @property
    def guessed_rate(self):
        """The guessed frame rate of this stream.

        This is a wrapper around :ffmpeg:`av_guess_frame_rate`, and uses multiple
        heuristics to decide what is "the" frame rate.

        :type: fractions.Fraction | None
        """
        val: lib.AVRational = lib.av_guess_frame_rate(
            cython.NULL, self.ptr, cython.NULL
        )
        return avrational_to_fraction(cython.address(val))

    @property
    def sample_aspect_ratio(self):
        """The guessed sample aspect ratio (SAR) of this stream.

        This is a wrapper around :ffmpeg:`av_guess_sample_aspect_ratio`, and uses multiple
        heuristics to decide what is "the" sample aspect ratio.

        :type: fractions.Fraction | None
        """
        sar: lib.AVRational = lib.av_guess_sample_aspect_ratio(
            self.container.ptr, self.ptr, cython.NULL
        )
        return avrational_to_fraction(cython.address(sar))

    @property
    def display_aspect_ratio(self):
        """The guessed display aspect ratio (DAR) of this stream.

        This is calculated from :meth:`.VideoStream.guessed_sample_aspect_ratio`.

        :type: fractions.Fraction | None
        """
        dar = cython.declare(lib.AVRational)
        lib.av_reduce(
            cython.address(dar.num),
            cython.address(dar.den),
            self.format.width * self.sample_aspect_ratio.num,
            self.format.height * self.sample_aspect_ratio.den,
            1024 * 1024,
        )

        return avrational_to_fraction(cython.address(dar))
