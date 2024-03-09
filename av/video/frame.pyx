import sys

from libc.stdint cimport uint8_t

from av.enum cimport define_enum
from av.error cimport err_check
from av.utils cimport check_ndarray, check_ndarray_shape
from av.video.format cimport get_pix_fmt, get_video_format
from av.video.plane cimport VideoPlane

import warnings

from av.deprecation import AVDeprecationWarning


cdef object _cinit_bypass_sentinel

cdef VideoFrame alloc_video_frame():
    """Get a mostly uninitialized VideoFrame.

    You MUST call VideoFrame._init(...) or VideoFrame._init_user_attributes()
    before exposing to the user.

    """
    return VideoFrame.__new__(VideoFrame, _cinit_bypass_sentinel)


PictureType = define_enum("PictureType", __name__, (
    ("NONE", lib.AV_PICTURE_TYPE_NONE, "Undefined"),
    ("I", lib.AV_PICTURE_TYPE_I, "Intra"),
    ("P", lib.AV_PICTURE_TYPE_P, "Predicted"),
    ("B", lib.AV_PICTURE_TYPE_B, "Bi-directional predicted"),
    ("S", lib.AV_PICTURE_TYPE_S, "S(GMC)-VOP MPEG-4"),
    ("SI", lib.AV_PICTURE_TYPE_SI, "Switching intra"),
    ("SP", lib.AV_PICTURE_TYPE_SP, "Switching predicted"),
    ("BI", lib.AV_PICTURE_TYPE_BI, "BI type"),
))


cdef byteswap_array(array, bint big_endian):
    if (sys.byteorder == "big") != big_endian:
        return array.byteswap()
    else:
        return array


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
        # Let go of the reference from the numpy buffers if we made one
        self._np_buffer = None

    def __repr__(self):
        return (
            f"<av.{self.__class__.__name__} #{self.index}, pts={self.pts} "
            f"{self.format.name} {self.width}x{self.height} at 0x{id(self):x}>"
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
    def key_frame(self):
        """Is this frame a key frame?

        Wraps :ffmpeg:`AVFrame.key_frame`.

        """
        return self.ptr.key_frame


    @property
    def interlaced_frame(self):
        """Is this frame an interlaced or progressive?

        Wraps :ffmpeg:`AVFrame.interlaced_frame`.

        """
        return self.ptr.interlaced_frame


    @property
    def pict_type(self):
        """One of :class:`.PictureType`.

        Wraps :ffmpeg:`AVFrame.pict_type`.

        """
        return PictureType.get(self.ptr.pict_type, create=True)

    @pict_type.setter
    def pict_type(self, value):
        self.ptr.pict_type = PictureType[value].value

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

    def to_ndarray(self, **kwargs):
        """Get a numpy array of this frame.

        Any ``**kwargs`` are passed to :meth:`.VideoReformatter.reformat`.

        .. note:: Numpy must be installed.

        .. note:: For formats which return an array of ``uint16`, the samples
        will be in the system's native byte order.

        .. note:: For ``pal8``, an ``(image, palette)`` tuple will be returned,
        with the palette being in ARGB (PyAV will swap bytes if needed).

        """
        cdef VideoFrame frame = self.reformat(**kwargs)

        import numpy as np

        if frame.format.name in ("yuv420p", "yuvj420p"):
            assert frame.width % 2 == 0
            assert frame.height % 2 == 0
            return np.hstack((
                useful_array(frame.planes[0]),
                useful_array(frame.planes[1]),
                useful_array(frame.planes[2])
            )).reshape(-1, frame.width)
        elif frame.format.name in ("yuv444p", "yuvj444p"):
            return np.hstack((
                useful_array(frame.planes[0]),
                useful_array(frame.planes[1]),
                useful_array(frame.planes[2])
            )).reshape(-1, frame.height, frame.width)
        elif frame.format.name == "yuyv422":
            assert frame.width % 2 == 0
            assert frame.height % 2 == 0
            return useful_array(frame.planes[0], 2).reshape(frame.height, frame.width, -1)
        elif frame.format.name == "gbrp":
            array = np.empty((frame.height, frame.width, 3), dtype="uint8")
            array[:, :, 0] = useful_array(frame.planes[2], 1).reshape(-1, frame.width)
            array[:, :, 1] = useful_array(frame.planes[0], 1).reshape(-1, frame.width)
            array[:, :, 2] = useful_array(frame.planes[1], 1).reshape(-1, frame.width)
            return array
        elif frame.format.name in ("gbrp10be", "gbrp12be", "gbrp14be", "gbrp16be", "gbrp10le", "gbrp12le", "gbrp14le", "gbrp16le"):
            array = np.empty((frame.height, frame.width, 3), dtype="uint16")
            array[:, :, 0] = useful_array(frame.planes[2], 2, "uint16").reshape(-1, frame.width)
            array[:, :, 1] = useful_array(frame.planes[0], 2, "uint16").reshape(-1, frame.width)
            array[:, :, 2] = useful_array(frame.planes[1], 2, "uint16").reshape(-1, frame.width)
            return byteswap_array(array, frame.format.name.endswith("be"))
        elif frame.format.name in ("gbrpf32be", "gbrpf32le"):
            array = np.empty((frame.height, frame.width, 3), dtype="float32")
            array[:, :, 0] = useful_array(frame.planes[2], 4, "float32").reshape(-1, frame.width)
            array[:, :, 1] = useful_array(frame.planes[0], 4, "float32").reshape(-1, frame.width)
            array[:, :, 2] = useful_array(frame.planes[1], 4, "float32").reshape(-1, frame.width)
            return byteswap_array(array, frame.format.name.endswith("be"))
        elif frame.format.name in ("rgb24", "bgr24"):
            return useful_array(frame.planes[0], 3).reshape(frame.height, frame.width, -1)
        elif frame.format.name in ("argb", "rgba", "abgr", "bgra"):
            return useful_array(frame.planes[0], 4).reshape(frame.height, frame.width, -1)
        elif frame.format.name in ("gray", "gray8", "rgb8", "bgr8"):
            return useful_array(frame.planes[0]).reshape(frame.height, frame.width)
        elif frame.format.name in ("gray16be", "gray16le"):
            return byteswap_array(
                useful_array(frame.planes[0], 2, "uint16").reshape(frame.height, frame.width),
                frame.format.name == "gray16be",
            )
        elif frame.format.name in ("rgb48be", "rgb48le"):
            return byteswap_array(
                useful_array(frame.planes[0], 6, "uint16").reshape(frame.height, frame.width, -1),
                frame.format.name == "rgb48be",
            )
        elif frame.format.name in ("rgba64be", "rgba64le"):
            return byteswap_array(
                useful_array(frame.planes[0], 8, "uint16").reshape(frame.height, frame.width, -1),
                frame.format.name == "rgba64be",
            )
        elif frame.format.name == "pal8":
            image = useful_array(frame.planes[0]).reshape(frame.height, frame.width)
            palette = np.frombuffer(frame.planes[1], "i4").astype(">i4").reshape(-1, 1).view(np.uint8)
            return image, palette
        elif frame.format.name == "nv12":
            return np.hstack((
                useful_array(frame.planes[0]),
                useful_array(frame.planes[1], 2)
            )).reshape(-1, frame.width)
        else:
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
    def from_numpy_buffer(array, format="rgb24"):
        if format in ("rgb24", "bgr24"):
            check_ndarray(array, "uint8", 3)
            check_ndarray_shape(array, array.shape[2] == 3)
            height, width = array.shape[:2]
        elif format in ("gray", "gray8", "rgb8", "bgr8"):
            check_ndarray(array, "uint8", 2)
            height, width = array.shape[:2]
        elif format in ("yuv420p", "yuvj420p", "nv12"):
            check_ndarray(array, "uint8", 2)
            check_ndarray_shape(array, array.shape[0] % 3 == 0)
            check_ndarray_shape(array, array.shape[1] % 2 == 0)
            height, width = array.shape[:2]
            height = height // 6 * 4
        else:
            raise ValueError(f"Conversion from numpy array with format `{format}` is not yet supported")

        if not array.flags["C_CONTIGUOUS"]:
            raise ValueError("provided array must be C_CONTIGUOUS")

        frame = alloc_video_frame()
        frame._image_fill_pointers_numpy(array, width, height, format)
        return frame

    def _image_fill_pointers_numpy(self, buffer, width, height, format):
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
        res = lib.av_image_fill_linesizes(
            self.ptr.linesize,
            <lib.AVPixelFormat>self.ptr.format,
            width,
        )
        if res:
          err_check(res)

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
    def from_ndarray(array, format="rgb24"):
        """
        Construct a frame from a numpy array.

        .. note:: For formats which expect an array of ``uint16``, the samples
        must be in the system's native byte order.

        .. note:: for ``pal8``, an ``(image, palette)`` pair must be passed. `palette` must have shape (256, 4) and is given in ARGB format (PyAV will swap bytes if needed).
        """
        if format == "pal8":
            array, palette = array
            check_ndarray(array, "uint8", 2)
            check_ndarray(palette, "uint8", 2)
            check_ndarray_shape(palette, palette.shape == (256, 4))

            frame = VideoFrame(array.shape[1], array.shape[0], format)
            copy_array_to_plane(array, frame.planes[0], 1)
            frame.planes[1].update(palette.view(">i4").astype("i4").tobytes())
            return frame
        elif format in ("yuv420p", "yuvj420p"):
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
        elif format in ("yuv444p", "yuvj444p"):
            check_ndarray(array, "uint8", 3)
            check_ndarray_shape(array, array.shape[0] == 3)

            frame = VideoFrame(array.shape[2], array.shape[1], format)
            array = array.reshape(3, -1)
            copy_array_to_plane(array[0], frame.planes[0], 1)
            copy_array_to_plane(array[1], frame.planes[1], 1)
            copy_array_to_plane(array[2], frame.planes[2], 1)
            return frame
        elif format == "yuyv422":
            check_ndarray(array, "uint8", 3)
            check_ndarray_shape(array, array.shape[0] % 2 == 0)
            check_ndarray_shape(array, array.shape[1] % 2 == 0)
            check_ndarray_shape(array, array.shape[2] == 2)
        elif format == "gbrp":
            check_ndarray(array, "uint8", 3)
            check_ndarray_shape(array, array.shape[2] == 3)

            frame = VideoFrame(array.shape[1], array.shape[0], format)
            copy_array_to_plane(array[:, :, 1], frame.planes[0], 1)
            copy_array_to_plane(array[:, :, 2], frame.planes[1], 1)
            copy_array_to_plane(array[:, :, 0], frame.planes[2], 1)
            return frame
        elif format in ("gbrp10be", "gbrp12be", "gbrp14be", "gbrp16be", "gbrp10le", "gbrp12le", "gbrp14le", "gbrp16le"):
            check_ndarray(array, "uint16", 3)
            check_ndarray_shape(array, array.shape[2] == 3)

            frame = VideoFrame(array.shape[1], array.shape[0], format)
            copy_array_to_plane(byteswap_array(array[:, :, 1], format.endswith("be")), frame.planes[0], 2)
            copy_array_to_plane(byteswap_array(array[:, :, 2], format.endswith("be")), frame.planes[1], 2)
            copy_array_to_plane(byteswap_array(array[:, :, 0], format.endswith("be")), frame.planes[2], 2)
            return frame
        elif format in ("gbrpf32be", "gbrpf32le"):
            check_ndarray(array, "float32", 3)
            check_ndarray_shape(array, array.shape[2] == 3)

            frame = VideoFrame(array.shape[1], array.shape[0], format)
            copy_array_to_plane(byteswap_array(array[:, :, 1], format.endswith("be")), frame.planes[0], 4)
            copy_array_to_plane(byteswap_array(array[:, :, 2], format.endswith("be")), frame.planes[1], 4)
            copy_array_to_plane(byteswap_array(array[:, :, 0], format.endswith("be")), frame.planes[2], 4)
            return frame
        elif format in ("rgb24", "bgr24"):
            check_ndarray(array, "uint8", 3)
            check_ndarray_shape(array, array.shape[2] == 3)
        elif format in ("argb", "rgba", "abgr", "bgra"):
            check_ndarray(array, "uint8", 3)
            check_ndarray_shape(array, array.shape[2] == 4)
        elif format in ("gray", "gray8", "rgb8", "bgr8"):
            check_ndarray(array, "uint8", 2)
        elif format in ("gray16be", "gray16le"):
            check_ndarray(array, "uint16", 2)
            frame = VideoFrame(array.shape[1], array.shape[0], format)
            copy_array_to_plane(byteswap_array(array, format == "gray16be"), frame.planes[0], 2)
            return frame
        elif format in ("rgb48be", "rgb48le"):
            check_ndarray(array, "uint16", 3)
            check_ndarray_shape(array, array.shape[2] == 3)
            frame = VideoFrame(array.shape[1], array.shape[0], format)
            copy_array_to_plane(byteswap_array(array, format == "rgb48be"), frame.planes[0], 6)
            return frame
        elif format in ("rgba64be", "rgba64le"):
            check_ndarray(array, "uint16", 3)
            check_ndarray_shape(array, array.shape[2] == 4)
            frame = VideoFrame(array.shape[1], array.shape[0], format)
            copy_array_to_plane(byteswap_array(array, format == "rgba64be"), frame.planes[0], 8)
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

    def __getattribute__(self, attribute):
        # This method should be deleted when `frame.index` is removed
        if attribute == "index":
            warnings.warn("Using `frame.index` is deprecated.", AVDeprecationWarning)

        return Frame.__getattribute__(self, attribute)
