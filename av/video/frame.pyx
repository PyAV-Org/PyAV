from cpython cimport Py_INCREF, PyTuple_New, PyTuple_SET_ITEM

from av.video.plane cimport VideoPlane
from av.video.format cimport blank_video_format
from av.utils cimport err_check


cdef object _cinit_bypass_sentinel = object()
cdef VideoFrame blank_video_frame():
    """Be sure to call VideoFrame._init(...)!"""
    return VideoFrame.__new__(VideoFrame, _cinit_bypass_sentinel)


cdef class VideoFrame(Frame):

    """A frame of video."""

    def __cinit__(self, unsigned int width=0, unsigned int height=0, format=b'yuv420p'):

        self.ptr = lib.avcodec_alloc_frame()
        lib.avcodec_get_frame_defaults(self.ptr)

        cdef lib.AVPixelFormat c_format = lib.av_get_pix_fmt(format)
        if c_format < 0:
            raise ValueError('invalid format %r' % format)

        self._init(c_format, width, height)

    cdef _init(self, lib.AVPixelFormat format, unsigned int width, unsigned int height):

        self.ptr.width = width
        self.ptr.height = height
        self.ptr.format = format

        self.format = blank_video_format()
        self.format._init(format, width, height)

        cdef int buffer_size
        cdef int plane_count = 0
        cdef VideoPlane p

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

            # Construct the planes.
            for i in range(lib.AV_NUM_DATA_POINTERS):
                if self.ptr.data[i]:
                    plane_count = i + 1
                else:
                    break
            self.planes = PyTuple_New(plane_count)
            for i in range(plane_count):
                p = VideoPlane(self, i)
                # We are constructing this tuple manually, but since Cython does
                # not understand reference stealing we must manually Py_INCREF
                # so that when Cython Py_DECREFs it doesn't release our object.
                Py_INCREF(p)
                PyTuple_SET_ITEM(self.planes, i, p)

        else:
            self.planes = ()


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
        
        cdef VideoFrame frame = blank_video_frame()
        frame._init(dst_format, width, height)
        
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
        import Image
        return Image.frombuffer("RGB", (self.width, self.height), self.to_rgb().planes[0], "raw", "RGB", 0, 1)




