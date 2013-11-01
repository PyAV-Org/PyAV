from libc.string cimport memcpy
from libc.stdlib cimport malloc, free
cimport cpython as cpy
from av.utils cimport err_check


cdef class VideoFrame(Frame):

    """A frame of video."""
    
    def __cinit__(self, unsigned int width=0, unsigned int height=0, bytes format=b'yuv420p'):

        cdef lib.AVPixelFormat c_format = lib.av_get_pix_fmt(format)
        if c_format < 0:
            raise ValueError('invalid format %r' % format)

        self.ptr = lib.avcodec_alloc_frame()
        lib.avcodec_get_frame_defaults(self.ptr)

        self._init(width, height, c_format)

    cdef _init(self, unsigned int width, unsigned int height, lib.AVPixelFormat format):

        cdef lib.AVFrame *ptr = self.ptr
        ptr.width = width
        ptr.height = height
        ptr.format = format

        if width and height:
            self.buffer_size = err_check(lib.avpicture_get_size(format, width, height))
        else:
            self.buffer_size = 0

        if self.buffer_size:
            
            # Cleanup the old one.
            lib.av_freep(&self._buffer)

            self._buffer = <uint8_t *>lib.av_malloc(self.buffer_size)
            if not self._buffer:
                raise MemoryError("cannot allocate VideoFrame buffer")

            # Attach the AVPicture to our buffer.
            lib.avpicture_fill(
                    <lib.AVPicture *>ptr,
                    self._buffer,
                    format,
                    width,
                    height
            )

    def __dealloc__(self):
        lib.av_freep(&self._buffer)

    def __repr__(self):
        return '<%s.%s %dx%d %s at 0x%x>' % (
            self.__class__.__module__,
            self.__class__.__name__,
            self.width,
            self.height,
            self.format,
            id(self),
        )
        
    def to_rgb(self):
        """Get an RGB version of this frame.

        >>> frame.format
        'yuv420p'
        >>> frame.to_rgb().format
        'rgb24'

        """
        return self.reformat(self.width, self.height, "rgb24")

    cpdef reformat(self, int width, int height, char* dst_format_str):
    
        """reformat(width, height, format)

        Create a new :class:`VideoFrame` with the given width/height/format.

        :param int width: New width.
        :param int height: New height.
        :param bytes format: New format; see :attr:`VideoFrame.format`.

        """
        
        if self.ptr.format < 0:
            raise ValueError("invalid source format")

        cdef lib.AVPixelFormat dst_format = lib.av_get_pix_fmt(dst_format_str)
        if dst_format == lib.AV_PIX_FMT_NONE:
            raise ValueError("invalid format %s" % dst_format_str)
        
        cdef lib.AVPixelFormat src_format = <lib.AVPixelFormat> self.ptr.format
        
        # Shortcut!
        if dst_format == src_format and width == self.ptr.width and height == self.ptr.height:
            return self

        # If VideoFrame doesn't have a SwsContextProxy create one
        if not self.sws_proxy:
            self.sws_proxy = SwsContextProxy()
        
        # Try and reuse existing SwsContextProxy
        # VideoStream.decode will copy its SwsContextProxy to VideoFrame
        # So all Video frames from the same VideoStream should have the same one
        
        self.sws_proxy.ptr = lib.sws_getCachedContext(
            self.sws_proxy.ptr,
            self.ptr.width,
            self.ptr.height,
            src_format,
            width,
            height,
            dst_format,
            lib.SWS_BILINEAR,
            NULL,
            NULL,
            NULL
        )
        
        # Create a new VideoFrame
        
        cdef VideoFrame frame = VideoFrame()
        frame._init(width, height, dst_format)
        
        # Finally Scale the image
        lib.sws_scale(
            self.sws_proxy.ptr,
            self.ptr.data,
            self.ptr.linesize,
            0, # slice Y
            self.ptr.height,
            frame.ptr.data,
            frame.ptr.linesize,
        )
        
        # Copy some properties.
        frame.frame_index = self.frame_index
        frame.time_base_ = self.time_base_
        frame.ptr.pts = self.ptr.pts
        
        return frame
        
    property width:
        """Width of the image, in pixels."""
        def __get__(self): return self.ptr.width

    property height:
        """Height of the image, in pixels."""
        def __get__(self): return self.ptr.height
    
    property format:
        """Pixel format of the image.

        :rtype: :class:`bytes` or ``None``.

        See ``ffmpeg -pix_fmts`` for all formats.

        >>> frame.format
        'yuv420p'

        """
        def __get__(self):
            result = lib.av_get_pix_fmt_name(<lib.AVPixelFormat>self.ptr.format)
            if result == NULL:
                return None
            return result
        
    property key_frame:
        """Is this frame a key frame?"""
        def __get__(self): return self.ptr.key_frame

    def update_from_string(self, bytes input):
        if len(input) != self.buffer_size:
            raise ValueError('got %d bytes; need %d bytes' % (len(input), self.buffer_size))
        memcpy(<void*>self.ptr.data[0], <void*><char*>input, self.buffer_size)

    def to_image(self):
        import Image
        return Image.frombuffer("RGB", (self.width, self.height), self.to_rgb(), "raw", "RGB", 0, 1)


    # Legacy buffer support. For `buffer` and PIL.
    # See: http://docs.python.org/2/c-api/typeobj.html#PyBufferProcs

    def __getsegcount__(self, Py_ssize_t *len_out):
        if len_out != NULL:
            len_out[0] = <Py_ssize_t>self.buffer_size
        return 1

    def __getreadbuffer__(self, Py_ssize_t index, void **data):
        if index:
            raise RuntimeError("accessing non-existent buffer segment")
        data[0] = <void*>self.ptr.data[0]
        return <Py_ssize_t>self.buffer_size

    def __getwritebuffer__(self, Py_ssize_t index, void **data):
        if index:
            raise RuntimeError("accessing non-existent buffer segment")
        data[0] = <void*>self.ptr.data[0]
        return <Py_ssize_t>self.buffer_size

    # PEP 3118 buffers. For `memoryviews`.
    # We cannot supply __releasebuffer__ or PIL will no longer think it can
    # take a read-only buffer. How silly.

    def __getbuffer__(self, Py_buffer *view, int flags):

        view.buf = <void*>self.ptr.data[0]
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


