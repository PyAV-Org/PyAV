cimport libav as lib

from av.bytesource cimport bytesource
from av.utils cimport avrational_to_fraction, to_avrational, err_check


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
            self.update_buffer(source)
            # TODO: Hold onto the source, and copy its pointer
            # instead of its data.
            #self.source = source

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
    cdef void*  _buffer_ptr(self):
        return self.struct.data
    #cdef bint _buffer_writable(self):
    #    return self.source is None

    def copy(self):
        raise NotImplementedError()
        cdef Packet copy = Packet()
        # copy.struct.size = self.struct.size
        # copy.struct.data = NULL
        return copy

    def decode(self, count=0):
        """Decode the data in this packet into a list of Frames."""
        return self._stream.decode(self, count)

    def decode_one(self):
        """Decode the first frame from this packet.

        Returns ``None`` if there is no frame."""
        res = self._stream.decode(self, count=1)
        return res[0] if res else None

    property stream_index:
        def __get__(self):
            return self.struct.stream_index

    property stream:
        def __get__(self):
            return self._stream
        def __set__(self, Stream stream):
            self._stream = stream
            self.struct.stream_index = stream._stream.index

    property pts:
        def __get__(self):
            if self.struct.pts != lib.AV_NOPTS_VALUE:
                return self.struct.pts
        def __set__(self, v):
            if v is None:
                self.struct.pts = lib.AV_NOPTS_VALUE
            else:
                self.struct.pts = v

    property dts:
        def __get__(self):
            if self.struct.dts != lib.AV_NOPTS_VALUE:
                return self.struct.dts
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

    property is_keyframe:
        def __get__(self): return bool(self.struct.flags & lib.AV_PKT_FLAG_KEY)

    property is_corrupt:
        def __get__(self): return bool(self.struct.flags & lib.AV_PKT_FLAG_CORRUPT)
