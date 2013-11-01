cdef class VideoFrame(Frame):

    """A frame of video."""

    def __dealloc__(self):
        # These are all NULL safe.
        lib.av_freep(&self.buffer_)
    
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
        frame.ptr = lib.avcodec_alloc_frame()
        lib.avcodec_get_frame_defaults(frame.ptr)
        
        # Calculate buffer size needed for new image
        frame.buffer_size = lib.avpicture_get_size(
            dst_format,
            width,
            height,
        )
        
        # Allocate the new Buffer
        frame.buffer_ = <uint8_t *>lib.av_malloc(frame.buffer_size * sizeof(uint8_t))
        
        if not frame.buffer_:
            raise MemoryError("Cannot allocate reformatted VideoFrame buffer")
        
        lib.avpicture_fill(
                <lib.AVPicture *>frame.ptr,
                frame.buffer_,
                dst_format,
                width,
                height
        )
        
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
        
        # Set new frame properties
        frame.ptr.width = width
        frame.ptr.height = height
        frame.ptr.format = dst_format
        
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

    # Legacy buffer support.
    # See: http://docs.python.org/2/c-api/typeobj.html#PyBufferProcs

    def __getsegcount__(self, Py_ssize_t *len_out):
        if len_out != NULL:
            len_out[0] = <Py_ssize_t> self.buffer_size
        return 1

    def __getreadbuffer__(self, Py_ssize_t index, void **data):
        if index:
            raise RuntimeError("accessing non-existent buffer segment")
        data[0] = <void*> self.ptr.data[0]
        return <Py_ssize_t> self.buffer_size
