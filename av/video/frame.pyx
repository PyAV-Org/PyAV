from av.utils cimport err_check, ByteSource, bytesource
from av.video.format cimport get_video_format, VideoFormat
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

    def __cinit__(self, width=0, height=0, format='yuv420p'):

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

    def to_colorspace(self,colorspace):
        """Get an versio of this frame in a different colorspace.
        :param str colorspace: New color format

        >>> frame = VideoFrame(1920, 1080)
        >>> frame.format.name
        'yuv420p'
        >>> frame.to_colorspace('rgb24').format.name
        'rgb24'

        """
        return self.reformat(self.width, self.height,colorspace)

    def reformat(self, unsigned int width, unsigned int height, dst_format_str, src_colorspace = None, dst_colorspace = None):

        """reformat(width, height, format)

        Create a new :class:`VideoFrame` with the given width/height/format.

        :param int width: New width.
        :param int height: New height.
        :param str format: New format; see :attr:`VideoFrame.format`.

        """

        cdef lib.AVPixelFormat dst_format = lib.av_get_pix_fmt(dst_format_str)
        if dst_format == lib.AV_PIX_FMT_NONE:
            raise ValueError("invalid format %r" % dst_format_str)


        colorspace_dict = {'itu709': lib.SWS_CS_ITU709,
                           'fcc': lib.SWS_CS_FCC,
                           'itu601': lib.SWS_CS_ITU601,
                           'itu624': lib.SWS_CS_SMPTE170M,
                           'smpte240': lib.SWS_CS_SMPTE240M,
                           'default': lib.SWS_CS_DEFAULT}

        cdef int cs_src = lib.SWS_CS_DEFAULT
        cdef int cs_dst = lib.SWS_CS_DEFAULT

        if not src_colorspace is None:
            cs_src = colorspace_dict[src_colorspace.lower()]

        if not dst_colorspace is None:
            cs_dst = colorspace_dict[dst_colorspace.lower()]


        return self._reformat(width, height, dst_format, cs_src, cs_dst)

    cdef _reformat(self, unsigned int width, unsigned int height, lib.AVPixelFormat dst_format, int src_colorspace, int dst_colorspace):

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
        with nogil:
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

        cdef int *inv_tbl = NULL
        cdef int *tbl = NULL
        cdef int *rgbTbl = NULL

        cdef int srcRange, dstRange, brightness, contrast, saturation

        cdef int ret

        ret = lib.sws_getColorspaceDetails(self.reformatter.ptr, &inv_tbl, &srcRange, &tbl, &dstRange, &brightness, &contrast, &saturation)

        # not all pix_fmt colorspace details supported should log...
        if not ret < 0:
            if src_colorspace != lib.SWS_CS_DEFAULT:
                inv_tbl = lib.sws_getCoefficients(src_colorspace)

            if dst_colorspace !=  lib.SWS_CS_DEFAULT:
                tbl = lib.sws_getCoefficients(dst_colorspace)

            lib.sws_setColorspaceDetails(self.reformatter.ptr, inv_tbl, srcRange, tbl, dstRange, brightness, contrast, saturation)

        # Create a new VideoFrame

        cdef VideoFrame frame = alloc_video_frame()
        frame._init(dst_format, width, height)

        # Finally Scale the image
        with nogil:
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
        frame._copy_attributes_from(self)
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
        from PIL import Image
        return Image.frombuffer("RGB", (self.width, self.height), self.to_rgb().planes[0], "raw", "RGB", 0, 1)

    def to_nd_array(self,colorspace="bgr24"):
        """
        numpy array from frame contents
        :param str colorspace: color format of image; Defaults to OpenCV convention.
        """
        import numpy as np
        return np.frombuffer(self.to_colorspace(colorspace).planes[0],np.uint8).reshape(self.height,self.width,-1)

    @classmethod
    def from_image(cls, img):
        if img.mode != 'RGB':
            img = img.convert('RGB')
        frame = cls(img.size[0], img.size[1], 'rgb24')

        # TODO: Use the buffer protocol.
        frame.planes[0].update(img.to_string())
        return frame

    @classmethod
    def from_ndarray(cls, array, format='rgb24'):

        # TODO: We could stand to be more accepting.
        assert array.ndim == 3
        assert array.shape[2] == 3
        assert array.dtype == 'uint8'

        frame = cls(array.shape[1], array.shape[0], format)
        frame.planes[0].update(array)

        return frame


