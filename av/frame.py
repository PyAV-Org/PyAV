import cython
from cython.cimports.av.error import err_check
from cython.cimports.av.opaque import opaque_container
from cython.cimports.av.utils import avrational_to_fraction, to_avrational

from av.sidedata.sidedata import SideDataContainer


@cython.cclass
class Frame:
    """
    Base class for audio and video frames.

    See also :class:`~av.audio.frame.AudioFrame` and :class:`~av.video.frame.VideoFrame`.
    """

    def __cinit__(self, *args, **kwargs):
        with cython.nogil:
            self.ptr = lib.av_frame_alloc()

    def __dealloc__(self):
        with cython.nogil:
            lib.av_frame_free(cython.address(self.ptr))

    def __repr__(self):
        return f"<av.{self.__class__.__name__} pts={self.pts} at 0x{id(self):x}>"

    @cython.cfunc
    def _copy_internal_attributes(self, source: Frame, data_layout: cython.bint = True):
        # Mimic another frame
        self._time_base = source._time_base
        lib.av_frame_copy_props(self.ptr, source.ptr)
        if data_layout:
            # TODO: Assert we don't have any data yet.
            self.ptr.format = source.ptr.format
            self.ptr.width = source.ptr.width
            self.ptr.height = source.ptr.height
            self.ptr.ch_layout = source.ptr.ch_layout

    @cython.cfunc
    def _init_user_attributes(self):
        pass  # Dummy to match the API of the others.

    @cython.cfunc
    def _rebase_time(self, dst: lib.AVRational):
        if not dst.num:
            raise ValueError("Cannot rebase to zero time.")

        if not self._time_base.num:
            self._time_base = dst
            return

        if self._time_base.num == dst.num and self._time_base.den == dst.den:
            return

        if self.ptr.pts != lib.AV_NOPTS_VALUE:
            self.ptr.pts = lib.av_rescale_q(self.ptr.pts, self._time_base, dst)

        if self.ptr.duration != 0:
            self.ptr.duration = lib.av_rescale_q(
                self.ptr.duration, self._time_base, dst
            )

        self._time_base = dst

    @property
    def dts(self):
        """
        The decoding timestamp copied from the :class:`~av.packet.Packet` that triggered returning this frame in :attr:`time_base` units.

        (if frame threading isn't used) This is also the Presentation time of this frame calculated from only :attr:`.Packet.dts` values without pts values.

        :type: int | None
        """
        if self.ptr.pkt_dts == lib.AV_NOPTS_VALUE:
            return None
        return self.ptr.pkt_dts

    @dts.setter
    def dts(self, value):
        if value is None:
            self.ptr.pkt_dts = lib.AV_NOPTS_VALUE
        else:
            self.ptr.pkt_dts = value

    @property
    def pts(self):
        """
        The presentation timestamp in :attr:`time_base` units for this frame.

        This is the time at which the frame should be shown to the user.

        :type: int | None
        """
        if self.ptr.pts == lib.AV_NOPTS_VALUE:
            return None
        return self.ptr.pts

    @pts.setter
    def pts(self, value):
        if value is None:
            self.ptr.pts = lib.AV_NOPTS_VALUE
        else:
            self.ptr.pts = value

    @property
    def duration(self):
        """
        The duration of the frame in :attr:`time_base` units

        :type: int
        """
        return self.ptr.duration

    @duration.setter
    def duration(self, value):
        self.ptr.duration = value

    @property
    def time(self):
        """
        The presentation time in seconds for this frame.

        This is the time at which the frame should be shown to the user.

        :type: float | None
        """
        if self.ptr.pts == lib.AV_NOPTS_VALUE:
            return None
        return float(self.ptr.pts) * self._time_base.num / self._time_base.den

    @property
    def time_base(self):
        """
        The unit of time (in fractional seconds) in which timestamps are expressed.

        :type: fractions.Fraction | None
        """
        if self._time_base.num:
            return avrational_to_fraction(cython.address(self._time_base))

    @time_base.setter
    def time_base(self, value):
        to_avrational(value, cython.address(self._time_base))

    @property
    def is_corrupt(self):
        """
        Is this frame corrupt?

        :type: bool
        """
        return self.ptr.decode_error_flags != 0 or bool(
            self.ptr.flags & lib.AV_FRAME_FLAG_CORRUPT
        )

    @property
    def key_frame(self):
        """Is this frame a key frame?

        Wraps :ffmpeg:`AVFrame.key_frame`.

        """
        return bool(self.ptr.flags & lib.AV_FRAME_FLAG_KEY)

    @key_frame.setter
    def key_frame(self, v):
        # PyAV makes no guarantees this does anything.
        if v:
            self.ptr.flags |= lib.AV_FRAME_FLAG_KEY
        else:
            self.ptr.flags &= ~lib.AV_FRAME_FLAG_KEY

    @property
    def side_data(self):
        if self._side_data is None:
            self._side_data = SideDataContainer(self)
        return self._side_data

    def make_writable(self):
        """
        Ensures that the frame data is writable. Copy the data to new buffer if it is not.
        This is a wrapper around :ffmpeg:`av_frame_make_writable`.
        """
        ret: cython.int = lib.av_frame_make_writable(self.ptr)
        err_check(ret)

    @property
    def opaque(self):
        if self.ptr.opaque_ref is not cython.NULL:
            return opaque_container.get(
                cython.cast(cython.p_char, self.ptr.opaque_ref.data)
            )

    @opaque.setter
    def opaque(self, v):
        lib.av_buffer_unref(cython.address(self.ptr.opaque_ref))

        if v is not None:
            self.ptr.opaque_ref = opaque_container.add(v)
