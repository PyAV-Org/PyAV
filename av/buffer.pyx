from libc.string cimport memcpy

from cpython cimport PyBuffer_FillInfo

from av.bytesource cimport ByteSource, bytesource


cdef class _Buffer(object):

    cdef size_t _buffer_size(self):
        return 0

    cdef void* _buffer_ptr(self):
        return NULL

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
        data[0] = self._buffer_ptr()
        return <Py_ssize_t>self._buffer_size()

    # New-style buffer support.

    def __getbuffer__(self, Py_buffer *view, int flags):
        PyBuffer_FillInfo(view, self, self._buffer_ptr(), self._buffer_size(), 0, flags)


cdef class Buffer(_Buffer):

    property buffer_size:
        def __get__(self):
            return self._buffer_size()

    property buffer_ptr:
        def __get__(self):
            return <size_t>self._buffer_ptr()

    def to_bytes(self):
        return <bytes>(<char*>self._buffer_ptr())[:self._buffer_size()]

    def update_buffer(self, input):
        """Replace the data in this object with the given buffer."""
        cdef ByteSource source = bytesource(input)
        cdef size_t size = self._buffer_size()
        if source.length != size:
            raise ValueError('got %d bytes; need %d bytes' % (len(input), size))
        memcpy(self._buffer_ptr(), source.ptr, size)

