from cpython cimport PyBUF_WRITABLE, PyBuffer_FillInfo
from libc.string cimport memcpy

from av.bytesource cimport ByteSource, bytesource


cdef class Buffer:
    """A base class for PyAV objects which support the buffer protocol, such
    as :class:`.Packet` and :class:`.Plane`.

    """

    cdef size_t _buffer_size(self):
        return 0

    cdef void* _buffer_ptr(self):
        return NULL

    cdef bint _buffer_writable(self):
        return True

    def __getbuffer__(self, Py_buffer *view, int flags):
        if flags & PyBUF_WRITABLE and not self._buffer_writable():
            raise ValueError("buffer is not writable")

        PyBuffer_FillInfo(view, self, self._buffer_ptr(), self._buffer_size(), 0, flags)

    @property
    def buffer_size(self):
        """The size of the buffer in bytes."""
        return self._buffer_size()

    @property
    def buffer_ptr(self):
        """The memory address of the buffer."""
        return <size_t>self._buffer_ptr()

    def update(self, input):
        """Replace the data in this object with the given buffer.

        Accepts anything that supports the `buffer protocol <https://docs.python.org/3/c-api/buffer.html>`_,
        e.g. bytes, Numpy arrays, other :class:`Buffer` objects, etc..

        """
        if not self._buffer_writable():
            raise ValueError("buffer is not writable")

        cdef ByteSource source = bytesource(input)
        cdef size_t size = self._buffer_size()

        if source.length != size:
            raise ValueError(f"got {source.length} bytes; need {size} bytes")

        memcpy(self._buffer_ptr(), source.ptr, size)
