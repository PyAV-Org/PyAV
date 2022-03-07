from libc.stdint cimport uint8_t

from av.enum cimport define_enum
from av.error cimport err_check
from av.utils cimport check_ndarray, check_ndarray_shape
from av.video.format cimport VideoFormat, get_pix_fmt, get_video_format
from av.video.plane cimport VideoPlane


cdef object _cinit_bypass_sentinel

cdef VideoFrame alloc_video_frame():
    """Get a mostly uninitialized VideoFrame.

    You MUST call VideoFrame._init(...) or VideoFrame._init_user_attributes()
    before exposing to the user.

    """
    return VideoFrame.__new__(VideoFrame, _cinit_bypass_sentinel)


PictureType = define_enum('PictureType', __name__, (
    ('NONE', lib.AV_PICTURE_TYPE_NONE, "Undefined"),
    ('I', lib.AV_PICTURE_TYPE_I, "Intra"),
    ('P', lib.AV_PICTURE_TYPE_P, "Predicted"),
    ('B', lib.AV_PICTURE_TYPE_B, "Bi-directional predicted"),
    ('S', lib.AV_PICTURE_TYPE_S, "S(GMC)-VOP MPEG-4"),
    ('SI', lib.AV_PICTURE_TYPE_SI, "Switching intra"),
    ('SP', lib.AV_PICTURE_TYPE_SP, "Switching predicted"),
    ('BI', lib.AV_PICTURE_TYPE_BI, "BI type"),
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

    def __cinit__(self, width=0, height=0, format='yuv420p'):

        if width is _cinit_bypass_sentinel:
            return

        cdef lib.AVPixelFormat c_format = get_pix_fmt(format)

        self._init(c_format, width, height)

    cdef _init(self, lib.AVPixelFormat format, unsigned int width, unsigned int height):

        cdef int res = 0

        with nogil:
            self.ptr.width = width
            self.ptr.height = height
            self.ptr.format = format

            # Allocate the buffer for the video frame.
            #
            # We enforce aligned buffers, otherwise `sws_scale` can perform
            # poorly or even cause out-of-bounds reads and writes.
            if width and height:
                res = lib.av_image_alloc(
                    self.ptr.data,
                    self.ptr.linesize,
                    width,
                    height,
                    format,
                    16)
                self._buffer = self.ptr.data[0]

        if res:
            err_check(res)

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

    @property
    def planes(self):
        """
        A tuple of :class:`.VideoPlane` objects.
        """
        # We need to detect which planes actually exist, but also contrain
        # ourselves to the maximum plane count (as determined only by VideoFrames
        # so far), in case the library implementation does not set the last
        # plane to NULL.
        cdef int max_plane_count = 0
        for i in range(self.format.ptr.nb_components):
            count = self.format.ptr.comp[i].plane + 1
            if max_plane_count < count:
                max_plane_count = count
        if self.format.name == 'pal8':
            max_plane_count = 2

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
        """Is this frame a key frame?

        Wraps :ffmpeg:`AVFrame.key_frame`.

        """
        def __get__(self): return self.ptr.key_frame

    property interlaced_frame:
        """Is this frame an interlaced or progressive?

        Wraps :ffmpeg:`AVFrame.interlaced_frame`.

        """
        def __get__(self): return self.ptr.interlaced_frame

    @property
    def pict_type(self):
        """One of :class:`.PictureType`.

        Wraps :ffmpeg:`AVFrame.pict_type`.

        """
        return PictureType.get(self.ptr.pict_type, create=True)

    @pict_type.setter
    def pict_type(self, value):
        self.ptr.pict_type = PictureType[value].value

    def reformat(self, *args, **kwargs):
        """reformat(width=None, height=None, format=None, src_colorspace=None, dst_colorspace=None, interpolation=None)

        Create a new :class:`VideoFrame` with the given width/height/format/colorspace.

        .. seealso:: :meth:`.VideoReformatter.reformat` for arguments.

        """
        if not self.reformatter:
            self.reformatter = VideoReformatter()
        return self.reformatter.reformat(self, *args, **kwargs)

    def to_rgb(self, **kwargs):
        """Get an RGB version of this frame.

        Any ``**kwargs`` are passed to :meth:`.VideoReformatter.reformat`.

        >>> frame = VideoFrame(1920, 1080)
        >>> frame.format.name
        'yuv420p'
        >>> frame.to_rgb().format.name
        'rgb24'

        """
        return self.reformat(format="rgb24", **kwargs)

    def to_image(self, **kwargs):
        """Get an RGB ``PIL.Image`` of this frame.

        Any ``**kwargs`` are passed to :meth:`.VideoReformatter.reformat`.

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

        return Image.frombytes("RGB", (plane.width, plane.height), bytes(o_buf), "raw", "RGB", 0, 1)

    def to_ndarray(self, **kwargs):
        """Get a numpy array of this frame.

        Any ``**kwargs`` are passed to :meth:`.VideoReformatter.reformat`.

        .. note:: Numpy must be installed.

        .. note:: For ``pal8``, an ``(image, palette)`` tuple will be returned,
        with the palette being in ARGB (PyAV will swap bytes if needed).

        """
        cdef VideoFrame frame = self.reformat(**kwargs)

        import numpy as np

        if frame.format.name in ('yuv420p', 'yuvj420p'):
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
        elif frame.format.name in ('gray', 'gray8', 'rgb8', 'bgr8'):
            return useful_array(frame.planes[0]).reshape(frame.height, frame.width)
        elif frame.format.name == 'pal8':
            image = useful_array(frame.planes[0]).reshape(frame.height, frame.width)
            palette = np.frombuffer(frame.planes[1], 'i4').astype('>i4').reshape(-1, 1).view(np.uint8)
            return image, palette
        else:
            raise ValueError('Conversion to numpy array with format `%s` is not yet supported' % frame.format.name)

    @staticmethod
    def from_image(img):
        """
        Construct a frame from a ``PIL.Image``.
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

        .. note:: for ``pal8``, an ``(image, palette)`` pair must be passed.
        `palette` must have shape (256, 4) and is given in ARGB format
        (PyAV will swap bytes if needed).
        """
        if format == 'pal8':
            array, palette = array
            check_ndarray(array, 'uint8', 2)
            check_ndarray(palette, 'uint8', 2)
            check_ndarray_shape(palette, palette.shape == (256, 4))

            frame = VideoFrame(array.shape[1], array.shape[0], format)
            copy_array_to_plane(array, frame.planes[0], 1)
            frame.planes[1].update(palette.view('>i4').astype('i4').tobytes())
            return frame
        elif format in ('yuv420p', 'yuvj420p'):
            check_ndarray(array, 'uint8', 2)
            check_ndarray_shape(array, array.shape[0] % 3 == 0)
            check_ndarray_shape(array, array.shape[1] % 2 == 0)

            frame = VideoFrame(array.shape[1], (array.shape[0] * 2) // 3, format)
            u_start = frame.width * frame.height
            v_start = 5 * u_start // 4
            flat = array.reshape(-1)
            copy_array_to_plane(flat[0:u_start], frame.planes[0], 1)
            copy_array_to_plane(flat[u_start:v_start], frame.planes[1], 1)
            copy_array_to_plane(flat[v_start:], frame.planes[2], 1)
            return frame
        elif format == 'yuyv422':
            check_ndarray(array, 'uint8', 3)
            check_ndarray_shape(array, array.shape[0] % 2 == 0)
            check_ndarray_shape(array, array.shape[1] % 2 == 0)
            check_ndarray_shape(array, array.shape[2] == 2)
        elif format in ('rgb24', 'bgr24'):
            check_ndarray(array, 'uint8', 3)
            check_ndarray_shape(array, array.shape[2] == 3)
        elif format in ('argb', 'rgba', 'abgr', 'bgra'):
            check_ndarray(array, 'uint8', 3)
            check_ndarray_shape(array, array.shape[2] == 4)
        elif format in ('gray', 'gray8', 'rgb8', 'bgr8'):
            check_ndarray(array, 'uint8', 2)
        else:
            raise ValueError('Conversion from numpy array with format `%s` is not yet supported' % format)

        frame = VideoFrame(array.shape[1], array.shape[0], format)
        copy_array_to_plane(array, frame.planes[0], 1 if array.ndim == 2 else array.shape[2])

        return frame
