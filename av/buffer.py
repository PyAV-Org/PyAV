import cython
from cython.cimports.cpython import PyBUF_WRITABLE, PyBuffer_FillInfo
from cython.cimports.cpython.buffer import (
    PyBUF_SIMPLE,
    PyBuffer_Release,
    PyObject_CheckBuffer,
    PyObject_GetBuffer,
)
from cython.cimports.libc.string import memcpy


@cython.cclass
class ByteSource:
    def __cinit__(self, owner):
        self.owner = owner

        try:
            self.ptr = owner
        except TypeError:
            pass
        else:
            self.length = len(owner)
            return

        if PyObject_CheckBuffer(owner):
            # Can very likely use PyBUF_ND instead of PyBUF_SIMPLE
            res = PyObject_GetBuffer(owner, cython.address(self.view), PyBUF_SIMPLE)
            if not res:
                self.has_view = True
                self.ptr = cython.cast(cython.p_uchar, self.view.buf)
                self.length = self.view.len
                return

        raise TypeError("expected bytes, bytearray or memoryview")

    def __dealloc__(self):
        if self.has_view:
            PyBuffer_Release(cython.address(self.view))


@cython.cfunc
def bytesource(obj, allow_none: cython.bint = False) -> ByteSource | None:
    if allow_none and obj is None:
        return None
    elif isinstance(obj, ByteSource):
        return obj
    else:
        return ByteSource(obj)


@cython.cclass
class Buffer:
    """A base class for PyAV objects which support the buffer protocol, such
    as :class:`.Packet` and :class:`.Plane`.

    """

    @cython.cfunc
    def _buffer_size(self) -> cython.size_t:
        return 0

    def _buffer_ptr(self) -> cython.p_void:
        return cython.NULL

    def _buffer_writable(self) -> cython.bint:
        return True

    def __getbuffer__(self, view: cython.pointer[Py_buffer], flags: cython.int):
        if flags & PyBUF_WRITABLE and not self._buffer_writable():
            raise ValueError("buffer is not writable")

        PyBuffer_FillInfo(view, self, self._buffer_ptr(), self._buffer_size(), 0, flags)

    @property
    def buffer_size(self):
        return self._buffer_size()

    @property
    def buffer_ptr(self):
        """The memory address of the buffer."""
        return cython.cast(cython.size_t, self._buffer_ptr())

    def update(self, input):
        """Replace the data in this object with the given buffer.

        Accepts anything that supports the `buffer protocol <https://docs.python.org/3/c-api/buffer.html>`_,
        e.g. bytes, NumPy arrays, other :class:`Buffer` objects, etc..

        """
        if not self._buffer_writable():
            raise ValueError("buffer is not writable")

        source: ByteSource = bytesource(input)
        size: cython.size_t = self._buffer_size()

        if source.length != size:
            raise ValueError(f"got {source.length} bytes; need {size} bytes")

        memcpy(self._buffer_ptr(), source.ptr, size)
