from libc.string cimport memcpy


cdef class VideoPlane(object):
    
    def __cinit__(self, VideoFrame frame, int index):
        self.frame = frame
        self.index = index
        for i in range(frame.format.ptr.nb_components):
            if frame.format.ptr.comp[i].plane == index:
                self.component = frame.format.components[i]
                break
        else:
            raise RuntimeError('could not find plane %d of %r' % (index, frame.format))

        self.buffer_size = self.frame.ptr.linesize[self.index] * self.component.height

    property width:
        """Pixel width of this plane."""
        def __get__(self):
            return self.component.width

    property height:
        """Pixel height of this plane."""
        def __get__(self):
            return self.component.height

    property line_size:
        """Bytes per horizontal line in this plane."""
        def __get__(self):
            return self.frame.ptr.linesize[self.index]

    def update_from_string(self, bytes input):
        """Replace the data in this plane with the given string."""
        if len(input) != self.buffer_size:
            raise ValueError('got %d bytes; need %d bytes' % (len(input), self.buffer_size))
        memcpy(<void*>self.frame.ptr.data[self.index], <void*><char*>input, self.buffer_size)

    # Legacy buffer support. For `buffer` and PIL.
    # See: http://docs.python.org/2/c-api/typeobj.html#PyBufferProcs

    def __getsegcount__(self, Py_ssize_t *len_out):
        if len_out != NULL:
            len_out[0] = <Py_ssize_t>self.buffer_size
        return 1

    def __getreadbuffer__(self, Py_ssize_t index, void **data):
        if index:
            raise RuntimeError("accessing non-existent buffer segment")
        data[0] = <void*>self.frame.ptr.data[self.index]
        return <Py_ssize_t>self.buffer_size

    def __getwritebuffer__(self, Py_ssize_t index, void **data):
        if index:
            raise RuntimeError("accessing non-existent buffer segment")
        data[0] = <void*>self.frame.ptr.data[self.index]
        return <Py_ssize_t>self.buffer_size

    # PEP 3118 buffers. For `memoryviews`.
    # We cannot supply __releasebuffer__ or PIL will no longer think it can
    # take a read-only buffer. How silly.

    def __getbuffer__(self, Py_buffer *view, int flags):

        view.buf = <void*>self.frame.ptr.data[self.index]
        view.len = <Py_ssize_t>self.buffer_size
        view.readonly = 0
        view.format = NULL
        view.ndim = 1
        view.itemsize = 1

        # We must hold onto these arrays, and share them amoung all buffers.
        # Please treat a Frame as immutable, okay?
        self._buffer_shape[0] = self.buffer_size
        view.shape = &self._buffer_shape[0]
        self._buffer_strides[0] = view.itemsize
        view.strides = &self._buffer_strides[0]
        self._buffer_suboffsets[0] = -1
        view.suboffsets = &self._buffer_suboffsets[0]
