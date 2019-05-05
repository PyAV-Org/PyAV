from libc.stdint cimport uint8_t

from av.deprecation import renamed_attr
from av.enums cimport define_enum
from av.utils cimport err_check
from av.video.format cimport get_video_format, VideoFormat
from av.video.plane cimport VideoPlane


cdef object _cinit_bypass_sentinel

cdef VideoFrame alloc_video_frame():
    """Get a mostly uninitialized VideoFrame.

    You MUST call VideoFrame._init(...) or VideoFrame._init_user_attributes()
    before exposing to the user.

    """
    return VideoFrame.__new__(VideoFrame, _cinit_bypass_sentinel)


PictureType = define_enum('PictureType', (
    ('NONE', lib.AV_PICTURE_TYPE_NONE),
    ('I', lib.AV_PICTURE_TYPE_I),
    ('P', lib.AV_PICTURE_TYPE_P),
    ('B', lib.AV_PICTURE_TYPE_B),
    ('S', lib.AV_PICTURE_TYPE_S),
    ('SI', lib.AV_PICTURE_TYPE_SI),
    ('SP', lib.AV_PICTURE_TYPE_SP),
    ('BI', lib.AV_PICTURE_TYPE_BI),
))


cdef copy_array_to_plane(array, VideoPlane plane, unsigned int bytes_per_pixel):
    cdef bytes imgbytes = array.tobytes()
    cdef const uint8_t[:] i_buf = imgbytes
    cdef size_t i_pos = 0
    cdef size_t i_stride = plane.width * bytes_per_pixel
    cdef size_t i_size = plane.height * i_stride

    cdef uint8_t[:] o_buf = plane
    cdef size_t o_pos = 0
    cdef size_t o_stride = abs(plane.line_size)

    while i_pos < i_size:
        o_buf[o_pos:o_pos + i_stride] = i_buf[i_pos:i_pos + i_stride]
        i_pos += i_stride
        o_pos += o_stride


cdef useful_array(VideoPlane plane, unsigned int bytes_per_pixel=1):
    """
    Return the useful part of the VideoPlane as a single dimensional array.

    We are simply discarding any padding which was added for alignment.
    """
    import numpy as np
    cdef size_t total_line_size = abs(plane.line_size)
    cdef size_t useful_line_size = plane.width * bytes_per_pixel
    arr = np.frombuffer(plane, np.uint8)
    if total_line_size != useful_line_size:
        arr = arr.reshape(-1, total_line_size)[:, 0:useful_line_size].reshape(-1)
    return arr


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
        with nogil:
            self.ptr.width = width
            self.ptr.height = height
            self.ptr.format = format

            # Allocate the buffer for the video frame.
            #
            # We enforce aligned buffers, otherwise `sws_scale` can perform
            # poorly or even cause out-of-bounds reads and writes.
            if width and height:
                ret = lib.av_image_alloc(
                    self.ptr.data,
                    self.ptr.linesize,
                    width,
                    height,
                    format,
                    16)
                with gil:
                    err_check(ret)
                self._buffer = self.ptr.data[0]

        self._init_user_attributes()

    cdef _init_user_attributes(self):
        self.format = get_video_format(<lib.AVPixelFormat>self.ptr.format, self.ptr.width, self.ptr.height)

    def __dealloc__(self):
        # The `self._buffer` member is only set if *we* allocated the buffer in `_init`,
        # as opposed to a buffer allocated by a decoder.
        lib.av_freep(&self._buffer)

    def __repr__(self):
        return '<av.%s #%d, pts=%s %s %dx%d at 0x%x>' % (
            self.__class__.__name__,
            self.index,
            self.pts,
            self.format.name,
            self.width,
            self.height,
            id(self),
        )

    def reformat(self, width=None, height=None, format=None, src_colorspace=None, dst_colorspace=None):
        """reformat(width=None, height=None, format=None, src_colorspace=None, dst_colorspace=None)

        Create a new :class:`VideoFrame` with the given width/height/format/colorspace.

        :param int width: New width, or ``None`` for the same width.
        :param int height: New height, or ``None`` for the same height.
        :param str format: New format, or ``None`` for the same format; see :attr:`VideoFrame.format`.
        :param str src_colorspace: Current colorspace.
        :param str dst_colorspace: Desired colorspace.

        Supported colorspaces are currently:
            - ``'itu709'``
            - ``'fcc'``
            - ``'itu601'``
            - ``'itu624'``
            - ``'smpte240'``
            - ``'default'`` or ``None``

        """

        cdef VideoFormat video_format = VideoFormat(format or self.format)

        colorspace_flags = {
            'itu709': lib.SWS_CS_ITU709,
            'fcc': lib.SWS_CS_FCC,
            'itu601': lib.SWS_CS_ITU601,
            'itu624': lib.SWS_CS_SMPTE170M,
            'smpte240': lib.SWS_CS_SMPTE240M,
            'default': lib.SWS_CS_DEFAULT,
            None: lib.SWS_CS_DEFAULT,
        }
        cdef int c_src_colorspace, c_dst_colorspace
        try:
            c_src_colorspace = colorspace_flags[src_colorspace]
        except KeyError:
            raise ValueError("Invalid src_colorspace %r" % src_colorspace)
        try:
            c_dst_colorspace = colorspace_flags[dst_colorspace]
        except KeyError:
            raise ValueError("Invalid dst_colorspace %r" % dst_colorspace)

        return self._reformat(width or self.width, height or self.height, video_format.pix_fmt, c_src_colorspace, c_dst_colorspace)

    cdef _reformat(self, int width, int height, lib.AVPixelFormat dst_format, int src_colorspace, int dst_colorspace):

        if self.ptr.format < 0:
            raise ValueError("Frame does not have format set.")

        cdef lib.AVPixelFormat src_format = <lib.AVPixelFormat> self.ptr.format

        # Shortcut!
        if (
            dst_format == src_format and
            width == self.ptr.width and
            height == self.ptr.height and
            dst_colorspace == src_colorspace
        ):
            return self

        # If we don't have a SwsContextProxy, create one.
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

        # We want to change the colorspace transforms. We do that by grabbing
        # all of the current settings, changing a couple, and setting them all.
        # We need a lot of state here.
        cdef const int *inv_tbl
        cdef const int *tbl
        cdef int src_range, dst_range, brightness, contrast, saturation
        cdef int ret
        if src_colorspace != dst_colorspace:

            with nogil:

                # Casts for const-ness, because Cython isn't expressive enough.
                ret = lib.sws_getColorspaceDetails(
                    self.reformatter.ptr,
                    <int**>&inv_tbl,
                    &src_range,
                    <int**>&tbl,
                    &dst_range,
                    &brightness,
                    &contrast,
                    &saturation
                )

            # I don't think this one can actually come up.
            if ret < 0:
                raise ValueError("Can't get colorspace of current format.")

            with nogil:

                # Grab the coefficients for the requested transforms.
                # The inv_table brings us to linear, and `tbl` to the new space.
                if src_colorspace != lib.SWS_CS_DEFAULT:
                    inv_tbl = lib.sws_getCoefficients(src_colorspace)
                if dst_colorspace != lib.SWS_CS_DEFAULT:
                    tbl = lib.sws_getCoefficients(dst_colorspace)

                # Apply!
                ret = lib.sws_setColorspaceDetails(self.reformatter.ptr, inv_tbl, src_range, tbl, dst_range, brightness, contrast, saturation)

            # This one can come up, but I'm not really sure in what scenarios.
            if ret < 0:
                raise ValueError("Can't set colorspace of current format.")

        # Create a new VideoFrame.
        cdef VideoFrame frame = alloc_video_frame()
        frame._copy_internal_attributes(self)
        frame._init(dst_format, width, height)

        # Finally, scale the image.
        with nogil:
            lib.sws_scale(
                self.reformatter.ptr,
                # Cast for const-ness, because Cython isn't expressive enough.
                <const uint8_t**>self.ptr.data,
                self.ptr.linesize,
                0,  # slice Y
                self.ptr.height,
                frame.ptr.data,
                frame.ptr.linesize,
            )

        return frame

    @property
    def planes(self):
        """
        A tuple of :class:`~av.video.plane.VideoPlane` objects.

        :type: tuple
        """
        # We need to detect which planes actually exist, but also contrain
        # ourselves to the maximum plane count (as determined only by VideoFrames
        # so far), in case the library implementation does not set the last
        # plane to NULL.
        cdef int max_plane_count = self.format.ptr.nb_components
        cdef int plane_count = 0
        while plane_count < max_plane_count and self.ptr.extended_data[plane_count]:
            plane_count += 1

        return tuple([VideoPlane(self, i) for i in range(plane_count)])

    property width:
        """Width of the image, in pixels."""
        def __get__(self): return self.ptr.width

    property height:
        """Height of the image, in pixels."""
        def __get__(self): return self.ptr.height

    property key_frame:
        """Is this frame a key frame?"""
        def __get__(self): return self.ptr.key_frame

    property interlaced_frame:
        """Is this frame an interlaced or progressive?"""
        def __get__(self): return self.ptr.interlaced_frame

    @property
    def pict_type(self):
        return PictureType.get(self.ptr.pict_type, create=True)

    @pict_type.setter
    def pict_type(self, value):
        self.ptr.pict_type = PictureType[value].value

    def to_rgb(self, **kwargs):
        """Get an RGB version of this frame.

        Any ``**kwargs`` are passed to :meth:`VideoFrame.reformat`.

        >>> frame = VideoFrame(1920, 1080)
        >>> frame.format.name
        'yuv420p'
        >>> frame.to_rgb().format.name
        'rgb24'

        """
        return self.reformat(format="rgb24", **kwargs)

    def to_image(self, **kwargs):
        """Get an RGB ``PIL.Image`` of this frame.

        Any ``**kwargs`` are passed to :meth:`VideoFrame.reformat`.

        .. note:: PIL or Pillow must be installed.

        """
        from PIL import Image
        cdef VideoPlane plane = self.reformat(format="rgb24", **kwargs).planes[0]

        cdef const uint8_t[:] i_buf = plane
        cdef size_t i_pos = 0
        cdef size_t i_stride = plane.line_size

        cdef size_t o_pos = 0
        cdef size_t o_stride = plane.width * 3
        cdef size_t o_size = plane.height * o_stride
        cdef bytearray o_buf = bytearray(o_size)

        while o_pos < o_size:
            o_buf[o_pos:o_pos + o_stride] = i_buf[i_pos:i_pos + o_stride]
            i_pos += i_stride
            o_pos += o_stride

        return Image.frombytes("RGB", (self.width, self.height), bytes(o_buf), "raw", "RGB", 0, 1)

    def to_ndarray(self, **kwargs):
        """Get a numpy array of this frame.

        Any ``**kwargs`` are passed to :meth:`VideoFrame.reformat`.

        .. note:: Numpy must be installed.

        """
        cdef VideoFrame frame = self.reformat(**kwargs)

        import numpy as np

        if frame.format.name == 'yuv420p':
            assert frame.width % 2 == 0
            assert frame.height % 2 == 0
            return np.hstack((
                useful_array(frame.planes[0]),
                useful_array(frame.planes[1]),
                useful_array(frame.planes[2])
            )).reshape(-1, frame.width)
        elif frame.format.name == 'yuyv422':
            assert frame.width % 2 == 0
            assert frame.height % 2 == 0
            return useful_array(frame.planes[0], 2).reshape(frame.height, frame.width, -1)
        elif frame.format.name in ('rgb24', 'bgr24'):
            return useful_array(frame.planes[0], 3).reshape(frame.height, frame.width, -1)
        elif frame.format.name in ('argb', 'rgba', 'abgr', 'bgra'):
            return useful_array(frame.planes[0], 4).reshape(frame.height, frame.width, -1)
        elif frame.format.name in ('gray', 'gray8'):
            return useful_array(frame.planes[0]).reshape(frame.height, frame.width)
        else:
            raise ValueError('Conversion to numpy array with format `%s` is not yet supported' % frame.format.name)

    to_nd_array = renamed_attr('to_ndarray')

    @staticmethod
    def from_image(img):
        """
        Construct a frame from a `PIL.Image`.
        """
        if img.mode != 'RGB':
            img = img.convert('RGB')

        cdef VideoFrame frame = VideoFrame(img.size[0], img.size[1], 'rgb24')
        copy_array_to_plane(img, frame.planes[0], 3)

        return frame

    @staticmethod
    def from_ndarray(array, format='rgb24'):
        """
        Construct a frame from a numpy array.
        """
        if format == 'yuv420p':
            assert array.dtype == 'uint8'
            assert array.ndim == 2
            assert array.shape[0] % 3 == 0
            assert array.shape[1] % 2 == 0
            frame = VideoFrame(array.shape[1], (array.shape[0] * 2) // 3, format)
            u_start = frame.width * frame.height
            v_start = 5 * u_start // 4
            flat = array.reshape(-1)
            copy_array_to_plane(flat[0:u_start], frame.planes[0], 1)
            copy_array_to_plane(flat[u_start:v_start], frame.planes[1], 1)
            copy_array_to_plane(flat[v_start:], frame.planes[2], 1)
            return frame
        elif format == 'yuyv422':
            assert array.dtype == 'uint8'
            assert array.ndim == 3
            assert array.shape[0] % 2 == 0
            assert array.shape[1] % 2 == 0
            assert array.shape[2] == 2
        elif format in ('rgb24', 'bgr24'):
            assert array.dtype == 'uint8'
            assert array.ndim == 3
            assert array.shape[2] == 3
        elif format in ('argb', 'rgba', 'abgr', 'bgra'):
            assert array.dtype == 'uint8'
            assert array.ndim == 3
            assert array.shape[2] == 4
        elif format in ('gray', 'gray8'):
            assert array.dtype == 'uint8'
            assert array.ndim == 2
        else:
            raise ValueError('Conversion from numpy array with format `%s` is not yet supported' % format)

        frame = VideoFrame(array.shape[1], array.shape[0], format)
        copy_array_to_plane(array, frame.planes[0], 1 if array.ndim == 2 else array.shape[2])

        return frame
