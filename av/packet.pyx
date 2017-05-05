cimport libav as lib
from libc.stdlib cimport malloc
from libc.string cimport memcpy

from av.bytesource cimport bytesource
from av.utils cimport avrational_to_faction


cdef class Packet(Buffer):
    
    """A packet of encoded data within a :class:`~av.format.Stream`.

    This may, or may not include a complete object within a stream.
    :meth:`decode` must be called to extract encoded data.

    """

    def __cinit__(self, input=None):
        lib.av_init_packet(&self.struct)
        self.struct.data = NULL
        self.struct.size = 0

    def __init__(self, input=None):
        cdef ByteSource source = bytesource(input, True)
        if source is not None:
            with nogil:
                self.struct.data = <unsigned char*>malloc(source.length)
                memcpy(self.struct.data, source.ptr, source.length)
                self.struct.size = source.length

    def __dealloc__(self):
        with nogil:
            if self.source is not None:
                self.struct.data = NULL
            # TODO: WTF happens with ref-counting?!
            lib.av_free_packet(&self.struct)
    
    def __repr__(self):
        return '<av.%s of #%d, dts=%s, pts=%s; %s bytes at 0x%x>' % (
            self.__class__.__name__,
            self.stream.index if self.stream else 0,
            self.dts,
            self.pts,
            self.struct.size,
            id(self),
        )
    
    # Buffer protocol.
    cdef size_t _buffer_size(self):
        return self.struct.size
    cdef void*  _buffer_ptr(self):
        return self.struct.data
    cdef bint _buffer_writable(self):
        return self.source is None

    def copy(self):
        raise NotImplementedError()
        cdef Packet copy = Packet()
        # copy.struct.size = self.struct.size
        # copy.struct.data = NULL
        return copy

    cdef int _retime(self, lib.AVRational src, lib.AVRational dst) except -1:

        if not src.num:
            src = self._time_base
        if not dst.num:
            dst = self._time_base

        if not src.num:
            raise ValueError('No src time_base.')
        if not dst.num:
            raise ValueError('No dst time_base.')

        if self.struct.pts != lib.AV_NOPTS_VALUE:
            self.struct.pts = lib.av_rescale_q(
                self.struct.pts,
                src, dst
            )
        if self.struct.dts != lib.AV_NOPTS_VALUE:
            self.struct.dts = lib.av_rescale_q(
                self.struct.dts,
                src, dst
            )
        if self.struct.duration > 0:
            self.struct.duration = lib.av_rescale_q(
                self.struct.duration,
                src, dst
            )

        self._time_base = dst
        return 0 # Just for exception.

    def decode(self, count=0):
        """Decode the data in this packet into a list of Frames."""
        return self.stream.decode(self, count)

    def decode_one(self):
        """Decode the first frame from this packet.

        Returns ``None`` if there is no frame."""
        res = self.stream.decode(self, count=1)
        return res[0] if res else None

    # Looks circular, but isn't. Silly Cython.
    property stream:
        def __get__(self):
            return self.stream
        def __set__(self, Stream value):

            # Rescale times.
            cdef lib.AVStream *old = self.stream._stream
            cdef lib.AVStream *new = value._stream
            if self.struct.pts != lib.AV_NOPTS_VALUE:
                self.struct.pts = lib.av_rescale_q_rnd(self.struct.pts, old.time_base, new.time_base, lib.AV_ROUND_NEAR_INF)
            if self.struct.dts != lib.AV_NOPTS_VALUE:
                self.struct.dts = lib.av_rescale_q_rnd(self.struct.dts, old.time_base, new.time_base, lib.AV_ROUND_NEAR_INF)
            self.struct.duration = lib.av_rescale_q(self.struct.duration, old.time_base, new.time_base)

            self.stream = value
            self.struct.stream_index = value.index

    property time_base:

        def __get__(self):
            return avrational_to_faction(&self._time_base)

        def __set__(self, value):
            self._time_base.num = value.numerator
            self._time_base.den = value.denominator

    property pts:
        def __get__(self): return None if self.struct.pts == lib.AV_NOPTS_VALUE else self.struct.pts
        def __set__(self, v):
            if v is None:
                self.struct.pts = lib.AV_NOPTS_VALUE
            else:
                self.struct.pts = v
    
    property dts:
        def __get__(self):
            return None if self.struct.dts == lib.AV_NOPTS_VALUE else self.struct.dts
        def __set__(self, v):
            if v is None:
                self.struct.dts = lib.AV_NOPTS_VALUE
            else:
                self.struct.dts = v
    
    property pos:
        def __get__(self): return None if self.struct.pos == -1 else self.struct.pos
    property size:
        def __get__(self): return self.struct.size
    property duration:
        def __get__(self): return None if self.struct.duration == lib.AV_NOPTS_VALUE else self.struct.duration

