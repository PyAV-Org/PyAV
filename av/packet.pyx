cimport libav as lib

from av.bytesource cimport bytesource
from av.error cimport err_check
from av.utils cimport avrational_to_fraction, to_avrational

from av import deprecation


cdef class Packet(Buffer):

    """A packet of encoded data within a :class:`~av.format.Stream`.

    This may, or may not include a complete object within a stream.
    :meth:`decode` must be called to extract encoded data.

    """

    def __cinit__(self, input=None):
        with nogil:
            lib.av_init_packet(&self.struct)

    def __init__(self, input=None):

        cdef size_t size = 0
        cdef ByteSource source = None

        if input is None:
            return

        if isinstance(input, (int, long)):
            size = input
        else:
            source = bytesource(input)
            size = source.length

        if size:
            err_check(lib.av_new_packet(&self.struct, size))

        if source is not None:
            self.update(source)
            # TODO: Hold onto the source, and copy its pointer
            # instead of its data.
            # self.source = source

    def __dealloc__(self):
        with nogil:
            lib.av_packet_unref(&self.struct)

    def __repr__(self):
        return '<av.%s of #%d, dts=%s, pts=%s; %s bytes at 0x%x>' % (
            self.__class__.__name__,
            self._stream.index if self._stream else 0,
            self.dts,
            self.pts,
            self.struct.size,
            id(self),
        )

    # Buffer protocol.
    cdef size_t _buffer_size(self):
        return self.struct.size
    cdef void* _buffer_ptr(self):
        return self.struct.data

    cdef _rebase_time(self, lib.AVRational dst):

        if not dst.num:
            raise ValueError('Cannot rebase to zero time.')

        if not self._time_base.num:
            self._time_base = dst
            return

        if self._time_base.num == dst.num and self._time_base.den == dst.den:
            return

        # TODO: Isn't there a function to do this?

        if self.struct.pts != lib.AV_NOPTS_VALUE:
            self.struct.pts = lib.av_rescale_q(
                self.struct.pts,
                self._time_base, dst
            )
        if self.struct.dts != lib.AV_NOPTS_VALUE:
            self.struct.dts = lib.av_rescale_q(
                self.struct.dts,
                self._time_base, dst
            )
        if self.struct.duration > 0:
            self.struct.duration = lib.av_rescale_q(
                self.struct.duration,
                self._time_base, dst
            )

        self._time_base = dst

    def decode(self):
        """
        Send the packet's data to the decoder and return a list of
        :class:`.AudioFrame`, :class:`.VideoFrame` or :class:`.SubtitleSet`.
        """
        return self._stream.decode(self)

    @deprecation.method
    def decode_one(self):
        """
        Send the packet's data to the decoder and return the first decoded frame.

        Returns ``None`` if there is no frame.

        .. warning:: This method is deprecated, as it silently discards any
                     other frames which were decoded.
        """
        res = self._stream.decode(self)
        return res[0] if res else None

    property stream_index:
        def __get__(self):
            return self.struct.stream_index

    property stream:
        """
        The :class:`Stream` this packet was demuxed from.
        """
        def __get__(self):
            return self._stream

        def __set__(self, Stream stream):
            self._stream = stream
            self.struct.stream_index = stream._stream.index

    property time_base:
        """
        The unit of time (in fractional seconds) in which timestamps are expressed.

        :type: fractions.Fraction
        """
        def __get__(self):
            return avrational_to_fraction(&self._time_base)

        def __set__(self, value):
            to_avrational(value, &self._time_base)

    property pts:
        """
        The presentation timestamp in :attr:`time_base` units for this packet.

        This is the time at which the packet should be shown to the user.

        :type: int
        """
        def __get__(self):
            if self.struct.pts != lib.AV_NOPTS_VALUE:
                return self.struct.pts

        def __set__(self, v):
            if v is None:
                self.struct.pts = lib.AV_NOPTS_VALUE
            else:
                self.struct.pts = v

    property dts:
        """
        The decoding timestamp in :attr:`time_base` units for this packet.

        :type: int
        """
        def __get__(self):
            if self.struct.dts != lib.AV_NOPTS_VALUE:
                return self.struct.dts

        def __set__(self, v):
            if v is None:
                self.struct.dts = lib.AV_NOPTS_VALUE
            else:
                self.struct.dts = v

    property pos:
        """
        The byte position of this packet within the :class:`.Stream`.

        Returns `None` if it is not known.

        :type: int
        """
        def __get__(self):
            if self.struct.pos != -1:
                return self.struct.pos

    property size:
        """
        The size in bytes of this packet's data.

        :type: int
        """
        def __get__(self):
            return self.struct.size

    property duration:
        """
        The duration in :attr:`time_base` units for this packet.

        Returns `None` if it is not known.

        :type: int
        """
        def __get__(self):
            if self.struct.duration != lib.AV_NOPTS_VALUE:
                return self.struct.duration

    property is_keyframe:
        def __get__(self): return bool(self.struct.flags & lib.AV_PKT_FLAG_KEY)

    property is_corrupt:
        def __get__(self): return bool(self.struct.flags & lib.AV_PKT_FLAG_CORRUPT)
