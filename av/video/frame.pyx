from av.utils cimport err_check
from av.video.format cimport get_video_format
from av.video.plane import VideoPlane


cdef object _cinit_bypass_sentinel

cdef VideoFrame alloc_video_frame():
    """Get a mostly uninitialized VideoFrame.

    You MUST call VideoFrame._init(...) or VideoFrame._init_properties()
    before exposing to the user.

    """
    return VideoFrame.__new__(VideoFrame, _cinit_bypass_sentinel)


cdef class VideoFrame(Frame):

    """A frame of video.

    >>> frame = VideoFrame(1920, 1080, 'rgb24')

    """

    def __cinit__(self, width=0, height=0, format=b'yuv420p'):

        if width is _cinit_bypass_sentinel:
            return

        cdef lib.AVPixelFormat c_format = lib.av_get_pix_fmt(format)
        if c_format < 0:
            raise ValueError('invalid format %r' % format)

        self._init(c_format, width, height)

    cdef _init(self, lib.AVPixelFormat format, unsigned int width, unsigned int height):

        self.ptr.width = width
        self.ptr.height = height
        self.ptr.format = format

        cdef int buffer_size

        if width and height:
            
            # Cleanup the old buffer.
            lib.av_freep(&self._buffer)

            # Get a new one.
            buffer_size = err_check(lib.avpicture_get_size(format, width, height))
            self._buffer = <uint8_t *>lib.av_malloc(buffer_size)
            if not self._buffer:
                raise MemoryError("cannot allocate VideoFrame buffer")

            # Attach the AVPicture to our buffer.
            lib.avpicture_fill(
                    <lib.AVPicture *>self.ptr,
                    self._buffer,
                    format,
                    width,
                    height
            )

        self._init_properties()

    cdef _init_properties(self):
        self.format = get_video_format(<lib.AVPixelFormat>self.ptr.format, self.ptr.width, self.ptr.height)
        self._init_planes(VideoPlane)

    def __dealloc__(self):
        lib.av_freep(&self._buffer)

    def __repr__(self):
        return '<av.%s #%d, %s %dx%d at 0x%x>' % (
            self.__class__.__name__,
            self.index,
            self.format.name,
            self.width,
            self.height,
            id(self),
        )
    

    def to_rgb(self):
        """Get an RGB version of this frame.

        >>> frame = VideoFrame(1920, 1080)
        >>> frame.format.name
        'yuv420p'
        >>> frame.to_rgb().format.name
        'rgb24'

        """
        return self.reformat(self.width, self.height, "rgb24")

    def reformat(self, unsigned int width, unsigned int height, char* dst_format_str):
    
        """reformat(width, height, format)

        Create a new :class:`VideoFrame` with the given width/height/format.

        :param int width: New width.
        :param int height: New height.
        :param bytes format: New format; see :attr:`VideoFrame.format`.

        """
        

        cdef lib.AVPixelFormat dst_format = lib.av_get_pix_fmt(dst_format_str)
        if dst_format == lib.AV_PIX_FMT_NONE:
            raise ValueError("invalid format %s" % dst_format_str)
        
        return self._reformat(width, height, dst_format)

    cdef _reformat(self, unsigned int width, unsigned int height, lib.AVPixelFormat dst_format):

        if self.ptr.format < 0:
            raise ValueError("invalid source format")

        cdef lib.AVPixelFormat src_format = <lib.AVPixelFormat> self.ptr.format
        
        # Shortcut!
        if dst_format == src_format and width == self.ptr.width and height == self.ptr.height:
            return self

        # If VideoFrame doesn't have a SwsContextProxy create one
        if not self.reformatter:
            self.reformatter = VideoReformatter()
        
        # Try and reuse existing SwsContextProxy
        # VideoStream.decode will copy its SwsContextProxy to VideoFrame
        # So all Video frames from the same VideoStream should have the same one
        
        self.reformatter.ptr = lib.sws_getCachedContext(
            self.reformatter.ptr,
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
        
        cdef VideoFrame frame = alloc_video_frame()
        frame._init(dst_format, width, height)
        
        # Finally Scale the image
        lib.sws_scale(
            self.reformatter.ptr,
            self.ptr.data,
            self.ptr.linesize,
            0, # slice Y
            self.ptr.height,
            frame.ptr.data,
            frame.ptr.linesize,
        )
        
        # Copy some properties.
        frame.index = self.index
        frame.time_base = self.time_base
        frame.ptr.pts = self.ptr.pts
        
        return frame
        
    property width:
        """Width of the image, in pixels."""
        def __get__(self): return self.ptr.width

    property height:
        """Height of the image, in pixels."""
        def __get__(self): return self.ptr.height
        
    property key_frame:
        """Is this frame a key frame?"""
        def __get__(self): return self.ptr.key_frame

    def to_image(self):
        import PIL.Image
        return PIL.Image.frombuffer("RGB", (self.width, self.height), self.to_rgb().planes[0], "raw", "RGB", 0, 1)

    @classmethod
    def from_image(cls, img):
        if img.mode != 'RGB':
            img = img.convert('RGB')
        frame = cls(img.size[0], img.size[1], 'rgb24')

        # TODO: Use the buffer protocol.
        frame.planes[0].update_from_string(img.to_string())
        return frame

    @classmethod
    def from_ndarray(cls, array, format='rgb24'):

        # TODO: We could stand to be more accepting.
        assert array.ndim == 3
        assert array.shape[2] == 3
        assert array.dtype == 'uint8'
        frame = cls(array.shape[1], array.shape[0], format)

        # TODO: Use the buffer protocol.
        frame.planes[0].update_from_string(array.tostring())

        return frame





