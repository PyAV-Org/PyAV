cimport libav as lib

from av.packet cimport Packet
from av.utils cimport avrational_to_fraction, to_avrational

from .frame cimport VideoFrame


cdef class VideoStream(Stream):
    def __repr__(self):
        return (
            f"<av.VideoStream #{self.index} {self.name}, "
            f"{self.format.name if self.format else None} {self.codec_context.width}x"
            f"{self.codec_context.height} at 0x{id(self):x}>"
        )

    cpdef encode(self, VideoFrame frame=None):
        """
        Encode an :class:`.VideoFrame` and return a list of :class:`.Packet`.

        :rtype: list[Packet]

        .. seealso:: This is mostly a passthrough to :meth:`.CodecContext.encode`.
        """

        packets = self.codec_context.encode(frame)
        cdef Packet packet
        for packet in packets:
            packet._stream = self
            packet.ptr.stream_index = self.ptr.index

        return packets


    cpdef decode(self, Packet packet=None):
        """
        Decode a :class:`.Packet` and return a list of :class:`.VideoFrame`.

        :rtype: list[VideoFrame]

        .. seealso:: This is a passthrough to :meth:`.CodecContext.decode`.
        """

        return self.codec_context.decode(packet)

    @property
    def average_rate(self):
        """
        The average frame rate of this video stream.

        This is calculated when the file is opened by looking at the first
        few frames and averaging their rate.

        :type: :class:`~fractions.Fraction` or ``None``
        """
        return avrational_to_fraction(&self.ptr.avg_frame_rate)

    @property
    def base_rate(self):
        """
        The base frame rate of this stream.

        This is calculated as the lowest framerate at which the timestamps of
        frames can be represented accurately. See :ffmpeg:`AVStream.r_frame_rate`
        for more.

        :type: :class:`~fractions.Fraction` or ``None``
        """
        return avrational_to_fraction(&self.ptr.r_frame_rate)

    @property
    def guessed_rate(self):
        """The guessed frame rate of this stream.

        This is a wrapper around :ffmpeg:`av_guess_frame_rate`, and uses multiple
        heuristics to decide what is "the" frame rate.

        :type: :class:`~fractions.Fraction` or ``None``
        """
        # The two NULL arguments aren't used in FFmpeg >= 4.0
        cdef lib.AVRational val = lib.av_guess_frame_rate(NULL, self.ptr, NULL)
        return avrational_to_fraction(&val)
