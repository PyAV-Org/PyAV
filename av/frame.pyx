from libc.limits cimport INT_MAX

from cpython cimport Py_INCREF, PyTuple_New, PyTuple_SET_ITEM

from av.plane cimport Plane
from av.utils cimport avrational_to_fraction, to_avrational

from fractions import Fraction


cdef class Frame(object):
    """
    Base class for audio and video frames.

    See also :class:`~av.audio.frame.AudioFrame` and :class:`~av.video.frame.VideoFrame`.
    """

    def __cinit__(self, *args, **kwargs):
        with nogil:
            self.ptr = lib.av_frame_alloc()

    def __dealloc__(self):
        with nogil:
            # This calls av_frame_unref, and then frees the pointer.
            # Thats it.
            lib.av_frame_free(&self.ptr)

    def __repr__(self):
        return 'av.%s #%d pts=%s at 0x%x>' % (
            self.__class__.__name__,
            self.index,
            id(self),
            self.pts,
        )

    cdef _init_planes(self, cls=Plane):

        # We need to detect which planes actually exist, but also contrain
        # ourselves to the maximum plane count (as determined only by VideoFrames
        # so far), in case the library implementation does not set the last
        # plane to NULL.
        cdef int max_plane_count = self._max_plane_count()
        cdef int plane_count = 0
        while plane_count < max_plane_count and self.ptr.extended_data[plane_count]:
            plane_count += 1

        self.planes = PyTuple_New(plane_count)
        for i in range(plane_count):
            # We are constructing this tuple manually, but since Cython does
            # not understand reference stealing we must manually Py_INCREF
            # so that when Cython Py_DECREFs it doesn't release our object.
            plane = cls(self, i)
            Py_INCREF(plane)
            PyTuple_SET_ITEM(self.planes, i, plane)

    cdef int _max_plane_count(self):
        return INT_MAX

    cdef _copy_internal_attributes(self, Frame source, bint data_layout=True):
        """Mimic another frame."""
        self.index = source.index
        self._time_base = source._time_base
        lib.av_frame_copy_props(self.ptr, source.ptr)
        if data_layout:
            # TODO: Assert we don't have any data yet.
            self.ptr.format = source.ptr.format
            self.ptr.width = source.ptr.width
            self.ptr.height = source.ptr.height
            self.ptr.channel_layout = source.ptr.channel_layout
            self.ptr.channels = source.ptr.channels

    cdef _init_user_attributes(self):
        pass # Dummy to match the API of the others.

    cdef _rebase_time(self, lib.AVRational dst):

        if not dst.num:
            raise ValueError('Cannot rebase to zero time.')

        if not self._time_base.num:
            self._time_base = dst
            return

        if self._time_base.num == dst.num and self._time_base.den == dst.den:
            return

        if self.ptr.pts != lib.AV_NOPTS_VALUE:
            self.ptr.pts = lib.av_rescale_q(
                self.ptr.pts,
                self._time_base, dst
            )

        self._time_base = dst

    property dts:
        """
        The decoding timestamp in :attr:`time_base` units for this frame.

        :type: int
        """
        def __get__(self):
            if self.ptr.pkt_dts == lib.AV_NOPTS_VALUE:
                return None
            return self.ptr.pkt_dts

    property pts:
        """
        The presentation timestamp in :attr:`time_base` units for this frame.

        This is the time at which the frame should be shown to the user.

        :type: int
        """
        def __get__(self):
            if self.ptr.pts == lib.AV_NOPTS_VALUE:
                return None
            return self.ptr.pts
        def __set__(self, value):
            if value is None:
                self.ptr.pts = lib.AV_NOPTS_VALUE
            else:
                self.ptr.pts = value

    property time:
        """
        The presentation time in seconds for this frame.

        This is the time at which the frame should be shown to the user.

        :type: float
        """
        def __get__(self):
            if self.ptr.pts == lib.AV_NOPTS_VALUE:
                return None
            else:
                return float(self.ptr.pts) * self._time_base.num / self._time_base.den

    property time_base:
        """
        The unit of time (in fractional seconds) in which timestamps are expressed.

        :type: fractions.Fraction
        """
        def __get__(self):
            if self._time_base.num:
                return avrational_to_fraction(&self._time_base)
        def __set__(self, value):
            to_avrational(value, &self._time_base)

    property is_corrupt:
        """
        Is this frame corrupt?

        :type: bool
        """
        def __get__(self): return self.ptr.decode_error_flags != 0 or bool(self.ptr.flags & lib.AV_FRAME_FLAG_CORRUPT)
