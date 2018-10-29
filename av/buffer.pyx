from libc.string cimport memcpy

from cpython cimport PyBuffer_FillInfo, PyBUF_WRITABLE

from av.bytesource cimport ByteSource, bytesource
from av.deprecation import renamed_attr


cdef class _Buffer(object):

    cdef size_t _buffer_size(self):
        return 0

    cdef void* _buffer_ptr(self):
        return NULL

    cdef bint _buffer_writable(self):
        return True

    # Legacy buffer support. For `buffer` and PIL.
    # See: http://docs.python.org/2/c-api/typeobj.html#PyBufferProcs

    def __getsegcount__(self, Py_ssize_t *len_out):
        if len_out != NULL:
            len_out[0] = <Py_ssize_t>self._buffer_size()
        return 1

    def __getreadbuffer__(self, Py_ssize_t index, void **data):
        if index:
            raise RuntimeError("accessing non-existent buffer segment")
        data[0] = self._buffer_ptr()
        return <Py_ssize_t>self._buffer_size()

    def __getwritebuffer__(self, Py_ssize_t index, void **data):
        if index:
            raise RuntimeError("accessing non-existent buffer segment")
        if not self._buffer_writable():
            raise ValueError('buffer is not writable')
        data[0] = self._buffer_ptr()
        return <Py_ssize_t>self._buffer_size()

    # New-style buffer support.
    def __getbuffer__(self, Py_buffer *view, int flags):
        if flags & PyBUF_WRITABLE and not self._buffer_writable():
            raise ValueError('buffer is not writable')
        PyBuffer_FillInfo(view, self, self._buffer_ptr(), self._buffer_size(), 0, flags)


cdef class Buffer(_Buffer):

    """A base class for PyAV objects which support the buffer protocol, such
    as :class:`.Packet` and :class:`.Plane`.

    """

    @property
    def buffer_size(self):
        """The size of the buffer in bytes."""
        return self._buffer_size()

    @property
    def buffer_ptr(self):
        """The memory address of the buffer."""
        return <size_t>self._buffer_ptr()

    def to_bytes(self):
        """Return the contents of this buffer as ``bytes``.
    
        This copies the entire contents; consider using something that uses
        the `buffer protocol <https://docs.python.org/3/c-api/buffer.html>`_
        as that will be more efficient.

        This is largely for Python2, as Python 3 can do the same via
        ``bytes(the_buffer)``.
        
        """
        return <bytes>(<char*>self._buffer_ptr())[:self._buffer_size()]

    def update(self, input):
        """Replace the data in this object with the given buffer.

        Accepts anything that supports the `buffer protocol <https://docs.python.org/3/c-api/buffer.html>`_,
        e.g. bytes, Numpy arrays, other :class:`Buffer` objects, etc..

        """
        if not self._buffer_writable():
            raise ValueError('buffer is not writable')
        cdef ByteSource source = bytesource(input)
        cdef size_t size = self._buffer_size()
        if source.length != size:
            raise ValueError('got %d bytes; need %d bytes' % (len(input), size))
        memcpy(self._buffer_ptr(), source.ptr, size)

    update_buffer = renamed_attr('update')
