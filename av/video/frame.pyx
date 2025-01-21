import sys
from enum import IntEnum

from libc.stdint cimport uint8_t

from av.error cimport err_check
from av.sidedata.sidedata cimport get_display_rotation
from av.utils cimport check_ndarray
from av.video.format cimport get_pix_fmt, get_video_format
from av.video.plane cimport VideoPlane


cdef object _cinit_bypass_sentinel

cdef VideoFrame alloc_video_frame():
    """Get a mostly uninitialized VideoFrame.

    You MUST call VideoFrame._init(...) or VideoFrame._init_user_attributes()
    before exposing to the user.

    """
    return VideoFrame.__new__(VideoFrame, _cinit_bypass_sentinel)

class PictureType(IntEnum):
    NONE = lib.AV_PICTURE_TYPE_NONE  # Undefined
    I = lib.AV_PICTURE_TYPE_I  # Intra
    P = lib.AV_PICTURE_TYPE_P  # Predicted
    B = lib.AV_PICTURE_TYPE_B  # Bi-directional predicted
    S = lib.AV_PICTURE_TYPE_S  # S(GMC)-VOP MPEG-4
    SI = lib.AV_PICTURE_TYPE_SI  # Switching intra
    SP = lib.AV_PICTURE_TYPE_SP  # Switching predicted
    BI = lib.AV_PICTURE_TYPE_BI  # BI type

cdef byteswap_array(array, bint big_endian):
    if (sys.byteorder == "big") != big_endian:
        return array.byteswap()
    else:
        return array


cdef copy_bytes_to_plane(img_bytes, VideoPlane plane, unsigned int bytes_per_pixel, bint flip_horizontal, bint flip_vertical):
    cdef const uint8_t[:] i_buf = img_bytes
    cdef size_t i_pos = 0
    cdef size_t i_stride = plane.width * bytes_per_pixel
    cdef size_t i_size = plane.height * i_stride

    cdef uint8_t[:] o_buf = plane
    cdef size_t o_pos = 0
    cdef size_t o_stride = abs(plane.line_size)

    cdef int start_row, end_row, step
    if flip_vertical:
        start_row = plane.height - 1
        end_row = -1
        step = -1
    else:
        start_row = 0
        end_row = plane.height
        step = 1

    cdef int i, j
    for row in range(start_row, end_row, step):
        i_pos = row * i_stride
        if flip_horizontal:
            for i in range(0, i_stride, bytes_per_pixel):
                for j in range(bytes_per_pixel):
                    o_buf[o_pos + i + j] = i_buf[i_pos + i_stride - i - bytes_per_pixel + j]
        else:
            o_buf[o_pos:o_pos + i_stride] = i_buf[i_pos:i_pos + i_stride]
        o_pos += o_stride


cdef copy_array_to_plane(array, VideoPlane plane, unsigned int bytes_per_pixel):
    cdef bytes imgbytes = array.tobytes()
    copy_bytes_to_plane(imgbytes, plane, bytes_per_pixel, False, False)


cdef useful_array(VideoPlane plane, unsigned int bytes_per_pixel=1, str dtype="uint8"):
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
    return arr.view(np.dtype(dtype))


cdef check_ndarray_shape(object array, bint ok):
    if not ok:
        raise ValueError(f"Unexpected numpy array shape `{array.shape}`")


cdef class VideoFrame(Frame):
    def __cinit__(self, width=0, height=0, format="yuv420p"):
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

            # We enforce aligned buffers, otherwise `sws_scale` can perform
            # poorly or even cause out-of-bounds reads and writes.
            if width and height:
                res = lib.av_image_alloc(
                    self.ptr.data, self.ptr.linesize, width, height, format, 16
                )
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
        # Let go of the reference from the numpy buffers if we made one
        self._np_buffer = None

    def __repr__(self):
        return (
            f"<av.{self.__class__.__name__}, pts={self.pts} {self.format.name} "
            f"{self.width}x{self.height} at 0x{id(self):x}>"
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
        if self.format.name == "pal8":
            max_plane_count = 2

        cdef int plane_count = 0
        while plane_count < max_plane_count and self.ptr.extended_data[plane_count]:
            plane_count += 1
        return tuple([VideoPlane(self, i) for i in range(plane_count)])

    @property
    def width(self):
        """Width of the image, in pixels."""
        return self.ptr.width

    @property
    def height(self):
        """Height of the image, in pixels."""
        return self.ptr.height

    @property
    def rotation(self):
        """The rotation component of the `DISPLAYMATRIX` transformation matrix.

        Returns:
            int: The angle (in degrees) by which the transformation rotates the frame
                counterclockwise. The angle will be in range [-180, 180].
        """
        return get_display_rotation(self)

    @property
    def interlaced_frame(self):
        """Is this frame an interlaced or progressive?"""

        return bool(self.ptr.flags & lib.AV_FRAME_FLAG_INTERLACED)

    @property
    def pict_type(self):
        """Returns an integer that corresponds to the PictureType enum.

        Wraps :ffmpeg:`AVFrame.pict_type`

        :type: int
        """
        return self.ptr.pict_type

    @pict_type.setter
    def pict_type(self, value):
        self.ptr.pict_type = value

    @property
    def colorspace(self):
        """Colorspace of frame.

        Wraps :ffmpeg:`AVFrame.colorspace`.

        """
        return self.ptr.colorspace

    @colorspace.setter
    def colorspace(self, value):
        self.ptr.colorspace = value

    @property
    def color_range(self):
        """Color range of frame.

        Wraps :ffmpeg:`AVFrame.color_range`.

        """
        return self.ptr.color_range

    @color_range.setter
    def color_range(self, value):
        self.ptr.color_range = value

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

    def to_ndarray(
        self,
        skip_channel: bool=True,
        gbr_to_rgb: bool=True,
        yuv444p_channel_first: bool=True,
        **kwargs
    ):
        """Get a numpy array of this frame.

        Any ``**kwargs`` are passed to :meth:`.VideoReformatter.reformat`.

        The array returned is generally of dimension (height, width, channels).

        :param bool skip_channel: If True, squeeze the channel dimension for grayscale frames.
        :param bool gbr_to_rgb: If True, for ``gbrp`` formats,
        channels are flipped to RGB order for backward compatibility.
        :param bool yuv444p_channel_first: If True, the shape for the yuv444p and yuvj444p
        will be (channels, height, width) rather than (height, width, channels) as usual.
        This is for backward compatibility.

        .. note:: Numpy must be installed.

        .. note:: For formats which return an array of ``uint16`, the samples
        will be in the system's native byte order.

        .. note:: For ``pal8``, an ``(image, palette)`` tuple will be returned,
        with the palette being in ARGB (PyAV will swap bytes if needed).

        """
        cdef VideoFrame frame = self.reformat(**kwargs)

        import numpy as np

        # check size
        if frame.format.name in {"yuv420p", "yuvj420p", "yuyv422"}:
            assert frame.width % 2 == 0, "the width has to be even for this pixel format"
            assert frame.height % 2 == 0, "the height has to be even for this pixel format"

        # cases planes are simply concatenated in shape (height, width, channels)
        itemsize, dtype = {
            "abgr": (4, "uint8"),
            "argb": (4, "uint8"),
            "bgr24": (3, "uint8"),
            "bgr8": (1, "uint8"),
            "bgra": (4, "uint8"),
            "gbrapf32be": (4, "float32"),
            "gbrapf32le": (4, "float32"),
            "gbrp": (1, "uint8"),
            "gbrp10be": (2, "uint16"),
            "gbrp10le": (2, "uint16"),
            "gbrp12be": (2, "uint16"),
            "gbrp12le": (2, "uint16"),
            "gbrp14be": (2, "uint16"),
            "gbrp14le": (2, "uint16"),
            "gbrp16be": (2, "uint16"),
            "gbrp16le": (2, "uint16"),
            "gbrpf32be": (4, "float32"),
            "gbrpf32le": (4, "float32"),
            "gray": (1, "uint8"),
            "gray16be": (2, "uint16"),
            "gray16le": (2, "uint16"),
            "gray8": (1, "uint8"),
            "grayf32be": (4, "float32"),
            "grayf32le": (4, "float32"),
            "rgb24": (3, "uint8"),
            "rgb48be": (6, "uint16"),
            "rgb48le": (6, "uint16"),
            "rgb8": (1, "uint8"),
            "rgba": (4, "uint8"),
            "rgba64be": (8, "uint16"),
            "rgba64le": (8, "uint16"),
            "yuv444p": (1, "uint8"),
            "yuv444p16be": (2, "uint16"),
            "yuv444p16le": (2, "uint16"),
            "yuva444p16be": (2, "uint16"),
            "yuva444p16le": (2, "uint16"),
            "yuvj444p": (1, "uint8"),
            "yuyv422": (2, "uint8"),
        }.get(frame.format.name, (None, None))
        if itemsize is not None:
            layers = [
                useful_array(plan, itemsize, dtype)
                .reshape(frame.height, frame.width, -1)
                for plan in frame.planes
            ]
            if len(layers) == 1:  # shortcut, avoid memory copy
                array = layers[0]
            else:  # general case
                array = np.concatenate(layers, axis=2)
            array = byteswap_array(array, frame.format.name.endswith("be"))
            if array.shape[2] == 1 and skip_channel:
                return array.squeeze(2)
            if gbr_to_rgb and frame.format.name.startswith("gbr"):
                buffer = array[:, :, 0].copy()
                array[:, :, 0] = array[:, :, 2]
                array[:, :, 2] = array[:, :, 1]
                array[:, :, 1] = buffer
            if yuv444p_channel_first and frame.format.name in {"yuv444p", "yuvj444p"}:
                array = np.moveaxis(array, 2, 0)
            return array

        # special cases
        if frame.format.name in {"yuv420p", "yuvj420p"}:
            return np.hstack([
                useful_array(frame.planes[0]),
                useful_array(frame.planes[1]),
                useful_array(frame.planes[2]),
            ]).reshape(-1, frame.width)
        if frame.format.name == "pal8":
            image = useful_array(frame.planes[0]).reshape(frame.height, frame.width)
            palette = np.frombuffer(frame.planes[1], "i4").astype(">i4").reshape(-1, 1).view(np.uint8)
            return image, palette
        if frame.format.name == "nv12":
            return np.hstack([
                useful_array(frame.planes[0]),
                useful_array(frame.planes[1], 2),
            ]).reshape(-1, frame.width)

        raise ValueError(
            f"Conversion to numpy array with format `{frame.format.name}` is not yet supported"
        )

    @staticmethod
    def from_image(img):
        """
        Construct a frame from a ``PIL.Image``.
        """
        if img.mode != "RGB":
            img = img.convert("RGB")

        cdef VideoFrame frame = VideoFrame(img.size[0], img.size[1], "rgb24")
        copy_array_to_plane(img, frame.planes[0], 3)

        return frame

    @staticmethod
    def from_numpy_buffer(array, format="rgb24", width=0):
        # Usually the width of the array is the same as the width of the image. But sometimes
        # this is not possible, for example with yuv420p images that have padding. These are
        # awkward because the UV rows at the bottom have padding bytes in the middle of the
        # row as well as at the end. To cope with these, callers need to be able to pass the
        # actual width to us.
        height = array.shape[0]
        if not width:
            width = array.shape[1]

        if format in ("rgb24", "bgr24"):
            check_ndarray(array, "uint8", 3)
            check_ndarray_shape(array, array.shape[2] == 3)
            if array.strides[1:] != (3, 1):
                raise ValueError("provided array does not have C_CONTIGUOUS rows")
            linesizes = (array.strides[0], )
        elif format in ("rgba", "bgra"):
            check_ndarray(array, "uint8", 3)
            check_ndarray_shape(array, array.shape[2] == 4)
            if array.strides[1:] != (4, 1):
                raise ValueError("provided array does not have C_CONTIGUOUS rows")
            linesizes = (array.strides[0], )
        elif format in ("gray", "gray8", "rgb8", "bgr8"):
            check_ndarray(array, "uint8", 2)
            if array.strides[1] != 1:
                raise ValueError("provided array does not have C_CONTIGUOUS rows")
            linesizes = (array.strides[0], )
        elif format in ("yuv420p", "yuvj420p", "nv12"):
            check_ndarray(array, "uint8", 2)
            check_ndarray_shape(array, array.shape[0] % 3 == 0)
            check_ndarray_shape(array, array.shape[1] % 2 == 0)
            height = height // 6 * 4
            if array.strides[1] != 1:
                raise ValueError("provided array does not have C_CONTIGUOUS rows")
            if format in ("yuv420p", "yuvj420p"):
                # For YUV420 planar formats, the UV plane stride is always half the Y stride.
                linesizes = (array.strides[0], array.strides[0] // 2, array.strides[0] // 2)
            else:
                # Planes where U and V are interleaved have the same stride as Y.
                linesizes = (array.strides[0], array.strides[0])
        else:
            raise ValueError(f"Conversion from numpy array with format `{format}` is not yet supported")

        frame = alloc_video_frame()
        frame._image_fill_pointers_numpy(array, width, height, linesizes, format)
        return frame

    def _image_fill_pointers_numpy(self, buffer, width, height, linesizes, format):
        cdef lib.AVPixelFormat c_format
        cdef uint8_t * c_ptr
        cdef size_t c_data

        # If you want to use the numpy notation
        # then you need to include the following two lines at the top of the file
        #      cimport numpy as cnp
        #      cnp.import_array()
        # And add the numpy include directories to the setup.py files
        # hint np.get_include()
        # cdef cnp.ndarray[
        #     dtype=cnp.uint8_t, ndim=1,
        #     negative_indices=False, mode='c'] c_buffer
        # c_buffer = buffer.reshape(-1)
        # c_ptr = &c_buffer[0]
        # c_ptr = <uint8_t*> (<void*>(buffer.ctypes.data))

        # Using buffer.ctypes.data helps avoid any kind of
        # usage of the c-api from numpy, which avoid the need to add numpy
        # as a compile time dependency
        # Without this double cast, you get an error that looks like
        #     c_ptr = <uint8_t*> (buffer.ctypes.data)
        # TypeError: expected bytes, int found
        c_data = buffer.ctypes.data
        c_ptr = <uint8_t*> (c_data)
        c_format = get_pix_fmt(format)
        lib.av_freep(&self._buffer)

        # Hold on to a reference for the numpy buffer
        # so that it doesn't get accidentally garbage collected
        self._np_buffer = buffer
        self.ptr.format = c_format
        self.ptr.width = width
        self.ptr.height = height
        for i, linesize in enumerate(linesizes):
            self.ptr.linesize[i] = linesize

        res = lib.av_image_fill_pointers(
            self.ptr.data,
            <lib.AVPixelFormat>self.ptr.format,
            self.ptr.height,
            c_ptr,
            self.ptr.linesize,
        )

        if res:
            err_check(res)
        self._init_user_attributes()

    @staticmethod
    def from_ndarray(array, format: str="rgb24", rgb_to_gbr: bool=True, yuv444p_channel_first: bool=True):
        """
        Construct a frame from a numpy array.

        :param bool rgb_to_gbr: If True, for ``gbrp`` formats,
        channels are assumed to be given in RGB order, for backward compatibility.
        :param bool yuv444p_channel_first: If True, the shape for the yuv444p and yuvj444p
        is given by (channels, height, width) rather than (height, width, channels).
        This is for backward compatibility.

        .. note:: For formats which expect an array of ``uint16``, the samples
        must be in the system's native byte order.

        .. note:: for ``pal8``, an ``(image, palette)`` pair must be passed. `palette` must have shape (256, 4) and is given in ARGB format (PyAV will swap bytes if needed).

        """
        import numpy as np

        # case layers are concatenated
        channels, itemsize, dtype = {
            "yuv444p": (3, 1, "uint8"),
            "yuvj444p": (3, 1, "uint8"),
            "gbrp": (3, 1, "uint8"),
            "gbrp10be": (3, 2, "uint16"),
            "gbrp12be": (3, 2, "uint16"),
            "gbrp14be": (3, 2, "uint16"),
            "gbrp16be": (3, 2, "uint16"),
            "gbrp10le": (3, 2, "uint16"),
            "gbrp12le": (3, 2, "uint16"),
            "gbrp14le": (3, 2, "uint16"),
            "gbrp16le": (3, 2, "uint16"),
            "gbrpf32be": (3, 4, "float32"),
            "gbrpf32le": (3, 4, "float32"),
            "gray": (1, 1, "uint8"),
            "gray8": (1, 1, "uint8"),
            "rgb8": (1, 1, "uint8"),
            "bgr8": (1, 1, "uint8"),
            "gray16be": (1, 2, "uint16"),
            "gray16le": (1, 2, "uint16"),
            "grayf32be": (1, 4, "float32"),
            "grayf32le": (1, 4, "float32"),
            "gbrapf32be": (4, 4, "float32"),
            "gbrapf32le": (4, 4, "float32"),
            "yuv444p16be": (3, 2, "uint16"),
            "yuv444p16le": (3, 2, "uint16"),
            "yuva444p16be": (4, 2, "uint16"),
            "yuva444p16le": (4, 2, "uint16"),
        }.get(format, (None, None, None))
        if channels is not None:
            if array.ndim == 2:  # (height, width) -> (height, width, 1)
                array = array[:, :, None]
            check_ndarray(array, dtype, 3)
            if format in {"yuv444p", "yuvj444p"}:
                array = np.moveaxis(array, 0, 2)
            check_ndarray_shape(array, array.shape[2] == channels)
            array = byteswap_array(array, format.endswith("be"))
            frame = VideoFrame(array.shape[1], array.shape[0], format)
            if rgb_to_gbr and frame.format.name.startswith("gbr"):
                array = np.concatenate([  # not inplace to avoid bad surprises
                    array[:, :, 1:3], array[:, :, 0:1], array[:, :, 3:],
                ], axis=2)
            for i in range(channels):
                copy_array_to_plane(array[:, :, i], frame.planes[i], itemsize)
            return frame

        # other cases
        if format == "pal8":
            array, palette = array
            check_ndarray(array, "uint8", 2)
            check_ndarray(palette, "uint8", 2)
            check_ndarray_shape(palette, palette.shape == (256, 4))

            frame = VideoFrame(array.shape[1], array.shape[0], format)
            copy_array_to_plane(array, frame.planes[0], 1)
            frame.planes[1].update(palette.view(">i4").astype("i4").tobytes())
            return frame
        elif format in {"yuv420p", "yuvj420p"}:
            check_ndarray(array, "uint8", 2)
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
        elif format == "yuyv422":
            check_ndarray(array, "uint8", 3)
            check_ndarray_shape(array, array.shape[0] % 2 == 0)
            check_ndarray_shape(array, array.shape[1] % 2 == 0)
            check_ndarray_shape(array, array.shape[2] == 2)
        elif format in {"rgb24", "bgr24"}:
            check_ndarray(array, "uint8", 3)
            check_ndarray_shape(array, array.shape[2] == 3)
        elif format in {"argb", "rgba", "abgr", "bgra"}:
            check_ndarray(array, "uint8", 3)
            check_ndarray_shape(array, array.shape[2] == 4)
        elif format in {"rgb48be", "rgb48le"}:
            check_ndarray(array, "uint16", 3)
            check_ndarray_shape(array, array.shape[2] == 3)
            frame = VideoFrame(array.shape[1], array.shape[0], format)
            copy_array_to_plane(byteswap_array(array, format.endswith("be")), frame.planes[0], 6)
            return frame
        elif format in {"rgba64be", "rgba64le"}:
            check_ndarray(array, "uint16", 3)
            check_ndarray_shape(array, array.shape[2] == 4)
            frame = VideoFrame(array.shape[1], array.shape[0], format)
            copy_array_to_plane(byteswap_array(array, format.endswith("be")), frame.planes[0], 8)
            return frame
        elif format == "nv12":
            check_ndarray(array, "uint8", 2)
            check_ndarray_shape(array, array.shape[0] % 3 == 0)
            check_ndarray_shape(array, array.shape[1] % 2 == 0)

            frame = VideoFrame(array.shape[1], (array.shape[0] * 2) // 3, format)
            uv_start = frame.width * frame.height
            flat = array.reshape(-1)
            copy_array_to_plane(flat[:uv_start], frame.planes[0], 1)
            copy_array_to_plane(flat[uv_start:], frame.planes[1], 2)
            return frame
        else:
            raise ValueError(f"Conversion from numpy array with format `{format}` is not yet supported")

        frame = VideoFrame(array.shape[1], array.shape[0], format)
        copy_array_to_plane(array, frame.planes[0], 1 if array.ndim == 2 else array.shape[2])

        return frame

    @staticmethod
    def from_bytes(img_bytes: bytes, width: int, height: int, format="rgba", flip_horizontal=False, flip_vertical=False):
        frame = VideoFrame(width, height, format)
        if format == "rgba":
            copy_bytes_to_plane(img_bytes, frame.planes[0], 4, flip_horizontal, flip_vertical)
        else:
            raise NotImplementedError(f"Format '{format}' is not supported.")
        return frame
