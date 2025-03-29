import cython
from cython.cimports import libav as lib
from cython.cimports.av.bytesource import bytesource
from cython.cimports.av.error import err_check
from cython.cimports.av.opaque import opaque_container
from cython.cimports.av.utils import avrational_to_fraction, to_avrational


@cython.cclass
class Packet(Buffer):
    """A packet of encoded data within a :class:`~av.format.Stream`.

    This may, or may not include a complete object within a stream.
    :meth:`decode` must be called to extract encoded data.
    """

    def __cinit__(self, input=None):
        with cython.nogil:
            self.ptr = lib.av_packet_alloc()

    def __dealloc__(self):
        with cython.nogil:
            lib.av_packet_free(cython.address(self.ptr))

    def __init__(self, input=None):
        size: cython.size_t = 0
        source: ByteSource = None

        if input is None:
            return

        if isinstance(input, int):
            size = input
        else:
            source = bytesource(input)
            size = source.length

        if size:
            err_check(lib.av_new_packet(self.ptr, size))

        if source is not None:
            self.update(source)
            # TODO: Hold onto the source, and copy its pointer
            # instead of its data.
            # self.source = source

    def __repr__(self):
        stream = self._stream.index if self._stream else 0
        return (
            f"av.{self.__class__.__name__} of #{stream}, dts={self.dts},"
            f" pts={self.pts}; {self.ptr.size} bytes at 0x{id(self):x}>"
        )

    # Buffer protocol.
    @cython.cfunc
    def _buffer_size(self) -> cython.size_t:
        return self.ptr.size

    @cython.cfunc
    def _buffer_ptr(self) -> cython.p_void:
        return self.ptr.data

    @cython.cfunc
    def _rebase_time(self, dst: lib.AVRational):
        if not dst.num:
            raise ValueError("Cannot rebase to zero time.")

        if not self._time_base.num:
            self._time_base = dst
            return

        if self._time_base.num == dst.num and self._time_base.den == dst.den:
            return

        lib.av_packet_rescale_ts(self.ptr, self._time_base, dst)

        self._time_base = dst

    def decode(self):
        """
        Send the packet's data to the decoder and return a list of
        :class:`.AudioFrame`, :class:`.VideoFrame` or :class:`.SubtitleSet`.
        """
        return self._stream.decode(self)

    @property
    def stream_index(self):
        return self.ptr.stream_index

    @property
    def stream(self):
        """
        The :class:`Stream` this packet was demuxed from.
        """
        return self._stream

    @stream.setter
    def stream(self, stream: Stream):
        self._stream = stream
        self.ptr.stream_index = stream.ptr.index

    @property
    def time_base(self):
        """
        The unit of time (in fractional seconds) in which timestamps are expressed.

        :type: fractions.Fraction
        """
        return avrational_to_fraction(cython.address(self._time_base))

    @time_base.setter
    def time_base(self, value):
        to_avrational(value, cython.address(self._time_base))

    @property
    def pts(self):
        """
        The presentation timestamp in :attr:`time_base` units for this packet.

        This is the time at which the packet should be shown to the user.

        :type: int | None
        """
        if self.ptr.pts != lib.AV_NOPTS_VALUE:
            return self.ptr.pts

    @pts.setter
    def pts(self, v):
        if v is None:
            self.ptr.pts = lib.AV_NOPTS_VALUE
        else:
            self.ptr.pts = v

    @property
    def dts(self):
        """
        The decoding timestamp in :attr:`time_base` units for this packet.

        :type: int | None
        """
        if self.ptr.dts != lib.AV_NOPTS_VALUE:
            return self.ptr.dts

    @dts.setter
    def dts(self, v):
        if v is None:
            self.ptr.dts = lib.AV_NOPTS_VALUE
        else:
            self.ptr.dts = v

    @property
    def pos(self):
        """
        The byte position of this packet within the :class:`.Stream`.

        Returns `None` if it is not known.

        :type: int | None
        """
        if self.ptr.pos != -1:
            return self.ptr.pos

    @property
    def size(self):
        """
        The size in bytes of this packet's data.

        :type: int
        """
        return self.ptr.size

    @property
    def duration(self):
        """
        The duration in :attr:`time_base` units for this packet.

        Returns `None` if it is not known.

        :type: int
        """
        if self.ptr.duration != lib.AV_NOPTS_VALUE:
            return self.ptr.duration

    @duration.setter
    def duration(self, v):
        if v is None:
            self.ptr.duration = lib.AV_NOPTS_VALUE
        else:
            self.ptr.duration = v

    @property
    def is_keyframe(self):
        return bool(self.ptr.flags & lib.AV_PKT_FLAG_KEY)

    @is_keyframe.setter
    def is_keyframe(self, v):
        if v:
            self.ptr.flags |= lib.AV_PKT_FLAG_KEY
        else:
            self.ptr.flags &= ~(lib.AV_PKT_FLAG_KEY)

    @property
    def is_corrupt(self):
        return bool(self.ptr.flags & lib.AV_PKT_FLAG_CORRUPT)

    @is_corrupt.setter
    def is_corrupt(self, v):
        if v:
            self.ptr.flags |= lib.AV_PKT_FLAG_CORRUPT
        else:
            self.ptr.flags &= ~(lib.AV_PKT_FLAG_CORRUPT)

    @property
    def is_discard(self):
        return bool(self.ptr.flags & lib.AV_PKT_FLAG_DISCARD)

    @property
    def is_trusted(self):
        return bool(self.ptr.flags & lib.AV_PKT_FLAG_TRUSTED)

    @property
    def is_disposable(self):
        return bool(self.ptr.flags & lib.AV_PKT_FLAG_DISPOSABLE)

    @property
    def opaque(self):
        if self.ptr.opaque_ref is not cython.NULL:
            return opaque_container.get(
                cython.cast(cython.p_char, self.ptr.opaque_ref.data)
            )

    @opaque.setter
    def opaque(self, v):
        lib.av_buffer_unref(cython.address(self.ptr.opaque_ref))

        if v is None:
            return
        self.ptr.opaque_ref = opaque_container.add(v)
