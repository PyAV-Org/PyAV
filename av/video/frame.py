import sys
from enum import IntEnum

import cython
import cython.cimports.libav as lib
from cython.cimports.av.dictionary import Dictionary
from cython.cimports.av.error import err_check
from cython.cimports.av.sidedata.sidedata import get_display_rotation
from cython.cimports.av.utils import check_ndarray
from cython.cimports.av.video.format import get_pix_fmt, get_video_format
from cython.cimports.av.video.plane import DLManagedTensor, VideoPlane, kCPU, kCuda
from cython.cimports.cpython.exc import PyErr_Clear
from cython.cimports.cpython.pycapsule import (
    PyCapsule_GetPointer,
    PyCapsule_IsValid,
    PyCapsule_SetName,
)
from cython.cimports.cpython.ref import Py_DECREF, Py_INCREF
from cython.cimports.libc.stdint import int64_t, uint8_t


@cython.cclass
class CudaContext:
    def __cinit__(self, device_id: cython.int = 0, primary_ctx: cython.bint = True):
        self.device_id = device_id
        self.primary_ctx = primary_ctx
        self._device_ref = cython.NULL
        self._frames_cache = {}

    def __dealloc__(self):
        ref: cython.pointer[lib.AVBufferRef]

        for v in self._frames_cache.values():
            ref = cython.cast(
                cython.pointer[lib.AVBufferRef],
                cython.cast(cython.size_t, v),
            )
            lib.av_buffer_unref(cython.address(ref))
        self._frames_cache.clear()

        ref = self._device_ref
        if ref != cython.NULL:
            lib.av_buffer_unref(cython.address(ref))
            self._device_ref = cython.NULL

    @cython.cfunc
    def _get_device_ref(self) -> cython.pointer[lib.AVBufferRef]:
        device_ref: cython.pointer[lib.AVBufferRef] = self._device_ref
        if device_ref != cython.NULL:
            return device_ref

        device_ref = cython.NULL
        device_bytes = f"{self.device_id}".encode()
        c_device: cython.p_char = device_bytes
        options: Dictionary = Dictionary(
            {"primary_ctx": "1" if self.primary_ctx else "0"}
        )
        err_check(
            lib.av_hwdevice_ctx_create(
                cython.address(device_ref),
                lib.AV_HWDEVICE_TYPE_CUDA,
                c_device,
                options.ptr,
                0,
            )
        )
        self._device_ref = device_ref
        return device_ref

    @cython.cfunc
    def get_frames_ctx(
        self,
        sw_fmt: lib.AVPixelFormat,
        width: cython.int,
        height: cython.int,
    ) -> cython.pointer[lib.AVBufferRef]:
        key = (int(sw_fmt), int(width), int(height))
        cached = self._frames_cache.get(key)
        cached_ref: cython.pointer[lib.AVBufferRef]
        out_ref: cython.pointer[lib.AVBufferRef]

        if cached is not None:
            cached_ref = cython.cast(
                cython.pointer[lib.AVBufferRef],
                cython.cast(cython.size_t, cached),
            )
            out_ref = lib.av_buffer_ref(cached_ref)
            if out_ref == cython.NULL:
                raise MemoryError("av_buffer_ref() failed")
            return out_ref

        device_ref = self._get_device_ref()

        frames_ref: cython.pointer[lib.AVBufferRef] = lib.av_hwframe_ctx_alloc(
            device_ref
        )
        if frames_ref == cython.NULL:
            raise MemoryError("av_hwframe_ctx_alloc() failed")

        try:
            frames_ctx: cython.pointer[lib.AVHWFramesContext] = cython.cast(
                cython.pointer[lib.AVHWFramesContext], frames_ref.data
            )
            frames_ctx.format = get_pix_fmt(b"cuda")
            frames_ctx.sw_format = sw_fmt
            frames_ctx.width = int(width)
            frames_ctx.height = int(height)
            err_check(lib.av_hwframe_ctx_init(frames_ref))
        except Exception:
            lib.av_buffer_unref(cython.address(frames_ref))
            raise

        out_ref = lib.av_buffer_ref(frames_ref)
        if out_ref == cython.NULL:
            lib.av_buffer_unref(cython.address(frames_ref))
            raise MemoryError("av_buffer_ref() failed")

        self._frames_cache[key] = cython.cast(cython.size_t, frames_ref)
        return out_ref


@cython.cfunc
def _consume_dlpack(obj: object, stream: object) -> cython.pointer[DLManagedTensor]:
    capsule: object
    managed: cython.pointer[DLManagedTensor]

    if hasattr(obj, "__dlpack__"):
        capsule = obj.__dlpack__() if stream is None else obj.__dlpack__(stream=stream)
    else:
        capsule = obj

    if not PyCapsule_IsValid(capsule, b"dltensor"):
        PyErr_Clear()
        raise TypeError(
            "expected a DLPack capsule or an object implementing __dlpack__"
        )

    managed = cython.cast(
        cython.pointer[DLManagedTensor],
        PyCapsule_GetPointer(capsule, b"dltensor"),
    )
    if managed == cython.NULL:
        raise ValueError("PyCapsule_GetPointer returned NULL")

    if PyCapsule_SetName(capsule, b"used_dltensor") != 0:
        raise RuntimeError("PyCapsule_SetName failed")

    return managed


@cython.cfunc
@cython.nogil
@cython.exceptval(check=False)
def _dlpack_avbuffer_free(
    opaque: cython.p_void,
    data: cython.pointer[uint8_t],
) -> cython.void:
    managed: cython.pointer[DLManagedTensor] = cython.cast(
        cython.pointer[DLManagedTensor], opaque
    )
    if managed != cython.NULL:
        managed.deleter(managed)


@cython.cfunc
@cython.nogil
@cython.exceptval(check=False)
def _numpy_avbuffer_free(
    opaque: cython.p_void,
    data: cython.pointer[uint8_t],
) -> cython.void:
    if opaque != cython.NULL:
        with cython.gil:
            Py_DECREF(cython.cast(object, opaque))


_cinit_bypass_sentinel = object()

# `pix_fmt`s supported by Frame.to_ndarray() and Frame.from_ndarray()
supported_np_pix_fmts = {
    "abgr",
    "argb",
    "bayer_bggr16be",
    "bayer_bggr16le",
    "bayer_bggr8",
    "bayer_gbrg16be",
    "bayer_gbrg16le",
    "bayer_gbrg8",
    "bayer_grbg16be",
    "bayer_grbg16le",
    "bayer_grbg8",
    "bayer_rggb16be",
    "bayer_rggb16le",
    "bayer_rggb8",
    "bgr24",
    "bgr48be",
    "bgr48le",
    "bgr8",
    "bgra",
    "bgra64be",
    "bgra64le",
    "gbrap",
    "gbrap10be",
    "gbrap10le",
    "gbrap12be",
    "gbrap12le",
    "gbrap14be",
    "gbrap14le",
    "gbrap16be",
    "gbrap16le",
    "gbrapf32be",
    "gbrapf32le",
    "gbrp",
    "gbrp10be",
    "gbrp10le",
    "gbrp12be",
    "gbrp12le",
    "gbrp14be",
    "gbrp14le",
    "gbrp16be",
    "gbrp16le",
    "gbrp9be",
    "gbrp9le",
    "gbrpf32be",
    "gbrpf32le",
    "gray",
    "gray10be",
    "gray10le",
    "gray12be",
    "gray12le",
    "gray14be",
    "gray14le",
    "gray16be",
    "gray16le",
    "gray8",
    "gray9be",
    "gray9le",
    "grayf32be",
    "grayf32le",
    "nv12",
    "pal8",
    "rgb24",
    "rgb48be",
    "rgb48le",
    "rgb8",
    "rgba",
    "rgba64be",
    "rgba64le",
    "rgbaf16be",
    "rgbaf16le",
    "rgbaf32be",
    "rgbaf32le",
    "rgbf32be",
    "rgbf32le",
    "yuv420p",
    "yuv422p10le",
    "yuv444p",
    "yuv444p16be",
    "yuv444p16le",
    "yuva444p16be",
    "yuva444p16le",
    "yuvj420p",
    "yuvj444p",
    "yuyv422",
}

# Mapping from format name to (itemsize, dtype) for formats where planes
# are simply concatenated into shape (height, width, channels).
_np_pix_fmt_dtypes: dict[str, tuple[int, str]] = {
    "abgr": (4, "uint8"),
    "argb": (4, "uint8"),
    "bayer_bggr8": (1, "uint8"),
    "bayer_gbrg8": (1, "uint8"),
    "bayer_grbg8": (1, "uint8"),
    "bayer_rggb8": (1, "uint8"),
    "bayer_bggr16le": (2, "uint16"),
    "bayer_bggr16be": (2, "uint16"),
    "bayer_gbrg16le": (2, "uint16"),
    "bayer_gbrg16be": (2, "uint16"),
    "bayer_grbg16le": (2, "uint16"),
    "bayer_grbg16be": (2, "uint16"),
    "bayer_rggb16le": (2, "uint16"),
    "bayer_rggb16be": (2, "uint16"),
    "bgr24": (3, "uint8"),
    "bgr48be": (6, "uint16"),
    "bgr48le": (6, "uint16"),
    "bgr8": (1, "uint8"),
    "bgra": (4, "uint8"),
    "bgra64be": (8, "uint16"),
    "bgra64le": (8, "uint16"),
    "gbrap": (1, "uint8"),
    "gbrap10be": (2, "uint16"),
    "gbrap10le": (2, "uint16"),
    "gbrap12be": (2, "uint16"),
    "gbrap12le": (2, "uint16"),
    "gbrap14be": (2, "uint16"),
    "gbrap14le": (2, "uint16"),
    "gbrap16be": (2, "uint16"),
    "gbrap16le": (2, "uint16"),
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
    "gbrp9be": (2, "uint16"),
    "gbrp9le": (2, "uint16"),
    "gbrpf32be": (4, "float32"),
    "gbrpf32le": (4, "float32"),
    "gray": (1, "uint8"),
    "gray10be": (2, "uint16"),
    "gray10le": (2, "uint16"),
    "gray12be": (2, "uint16"),
    "gray12le": (2, "uint16"),
    "gray14be": (2, "uint16"),
    "gray14le": (2, "uint16"),
    "gray16be": (2, "uint16"),
    "gray16le": (2, "uint16"),
    "gray8": (1, "uint8"),
    "gray9be": (2, "uint16"),
    "gray9le": (2, "uint16"),
    "grayf32be": (4, "float32"),
    "grayf32le": (4, "float32"),
    "rgb24": (3, "uint8"),
    "rgb48be": (6, "uint16"),
    "rgb48le": (6, "uint16"),
    "rgb8": (1, "uint8"),
    "rgba": (4, "uint8"),
    "rgba64be": (8, "uint16"),
    "rgba64le": (8, "uint16"),
    "rgbaf16be": (8, "float16"),
    "rgbaf16le": (8, "float16"),
    "rgbaf32be": (16, "float32"),
    "rgbaf32le": (16, "float32"),
    "rgbf32be": (12, "float32"),
    "rgbf32le": (12, "float32"),
    "yuv444p": (1, "uint8"),
    "yuv444p16be": (2, "uint16"),
    "yuv444p16le": (2, "uint16"),
    "yuva444p16be": (2, "uint16"),
    "yuva444p16le": (2, "uint16"),
    "yuvj444p": (1, "uint8"),
    "yuyv422": (2, "uint8"),
}


@cython.cfunc
def alloc_video_frame() -> VideoFrame:
    """Get a mostly uninitialized VideoFrame.

    You MUST call VideoFrame._init(...) or VideoFrame._init_user_attributes()
    before exposing to the user.

    """
    return VideoFrame(_cinit_bypass_sentinel)


class PictureType(IntEnum):
    NONE = lib.AV_PICTURE_TYPE_NONE  # Undefined
    I = lib.AV_PICTURE_TYPE_I  # Intra
    P = lib.AV_PICTURE_TYPE_P  # Predicted
    B = lib.AV_PICTURE_TYPE_B  # Bi-directional predicted
    S = lib.AV_PICTURE_TYPE_S  # S(GMC)-VOP MPEG-4
    SI = lib.AV_PICTURE_TYPE_SI  # Switching intra
    SP = lib.AV_PICTURE_TYPE_SP  # Switching predicted
    BI = lib.AV_PICTURE_TYPE_BI  # BI type


@cython.cfunc
def byteswap_array(array, big_endian: cython.bint):
    if (sys.byteorder == "big") != big_endian:
        return array.byteswap()
    return array


@cython.cfunc
def copy_bytes_to_plane(
    img_bytes,
    plane: VideoPlane,
    bytes_per_pixel: cython.uint,
    flip_horizontal: cython.bint,
    flip_vertical: cython.bint,
):
    i_buf: cython.const[uint8_t][:] = img_bytes
    i_pos: cython.size_t = 0
    i_stride: cython.size_t = plane.width * bytes_per_pixel

    o_buf: uint8_t[:] = plane
    o_pos: cython.size_t = 0
    o_stride: cython.size_t = abs(plane.line_size)

    start_row, end_row, step = cython.declare(cython.int)
    if flip_vertical:
        start_row = plane.height - 1
        end_row = -1
        step = -1
    else:
        start_row = 0
        end_row = plane.height
        step = 1

    for row in range(start_row, end_row, step):
        i_pos = row * i_stride
        if flip_horizontal:
            i: cython.Py_ssize_t
            for i in range(0, i_stride, bytes_per_pixel):
                j: cython.Py_ssize_t
                for j in range(bytes_per_pixel):
                    o_buf[o_pos + i + j] = i_buf[
                        i_pos + i_stride - i - bytes_per_pixel + j
                    ]
        else:
            o_buf[o_pos : o_pos + i_stride] = i_buf[i_pos : i_pos + i_stride]
        o_pos += o_stride


@cython.cfunc
def copy_array_to_plane(array, plane: VideoPlane, bytes_per_pixel: cython.uint):
    imgbytes: bytes = array.tobytes()
    copy_bytes_to_plane(imgbytes, plane, bytes_per_pixel, False, False)


@cython.cfunc
def useful_array(
    plane: VideoPlane, bytes_per_pixel: cython.uint = 1, dtype: str = "uint8"
):
    """
    Return the useful part of the VideoPlane as a single dimensional array.

    We are simply discarding any padding which was added for alignment.
    """
    import numpy as np

    total_line_size: cython.size_t = abs(plane.line_size)
    useful_line_size: cython.size_t = plane.width * bytes_per_pixel
    if total_line_size == useful_line_size:
        return np.frombuffer(plane, dtype=dtype)
    arr = np.frombuffer(plane, np.uint8)
    arr = arr.reshape(-1, total_line_size)[:, 0:useful_line_size].reshape(-1)
    return arr.view(np.dtype(dtype))


@cython.cfunc
def check_ndarray_shape(array: object, ok: cython.bint):
    if not ok:
        raise ValueError(f"Unexpected numpy array shape `{array.shape}`")


@cython.cclass
class VideoFrame(Frame):
    def __cinit__(self, width=0, height=0, format="yuv420p"):
        if width is _cinit_bypass_sentinel:
            return

        c_format: lib.AVPixelFormat = get_pix_fmt(format)
        self._init(c_format, width, height)

    @cython.cfunc
    def _init(self, format: lib.AVPixelFormat, width: cython.uint, height: cython.uint):
        res: cython.int = 0

        with cython.nogil:
            self.ptr.width = width
            self.ptr.height = height
            self.ptr.format = format

            # We enforce aligned buffers, otherwise `sws_scale` can perform
            # poorly or even cause out-of-bounds reads and writes.
            if width and height:
                res = lib.av_frame_get_buffer(self.ptr, 16)

        if res:
            err_check(res)

        self._init_user_attributes()

    @cython.cfunc
    def _init_user_attributes(self):
        self.format = get_video_format(
            cython.cast(lib.AVPixelFormat, self.ptr.format),
            self.ptr.width,
            self.ptr.height,
        )

    def __dealloc__(self):
        lib.av_frame_unref(self.ptr)

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
        # We need to detect which planes actually exist, but also constrain ourselves to
        # the maximum plane count (as determined only by VideoFrames so far), in case
        # the library implementation does not set the last plane to NULL.
        fmt = self.format
        if self.ptr.hw_frames_ctx:
            frames_ctx: cython.pointer[lib.AVHWFramesContext] = cython.cast(
                cython.pointer[lib.AVHWFramesContext], self.ptr.hw_frames_ctx.data
            )
            fmt = get_video_format(
                frames_ctx.sw_format, self.ptr.width, self.ptr.height
            )

        max_plane_count: cython.int = 0
        for i in range(fmt.ptr.nb_components):
            count = fmt.ptr.comp[i].plane + 1
            if max_plane_count < count:
                max_plane_count = count
        if fmt.name == "pal8":
            max_plane_count = 2

        plane_count: cython.int = 0
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

    @cython.ccall
    def save(self, filepath: object):
        """Save a VideoFrame as a JPG or PNG.

        :param filepath: str | Path
        """
        is_jpg: cython.bint

        if filepath.endswith(".png"):
            is_jpg = False
        elif filepath.endswith(".jpg") or filepath.endswith(".jpeg"):
            is_jpg = True
        else:
            raise ValueError("filepath must end with png or jpg.")

        encoder: str = "mjpeg" if is_jpg else "png"
        pix_fmt: str = "yuvj420p" if is_jpg else "rgb24"

        from av.container.core import open

        with open(filepath, "w", options={"update": "1"}) as output:
            output_stream = output.add_stream(encoder, pix_fmt=pix_fmt)
            output_stream.width = self.width
            output_stream.height = self.height

            output.mux(output_stream.encode(self.reformat(format=pix_fmt)))
            output.mux(output_stream.encode(None))

    def to_image(self, **kwargs):
        """Get an RGB ``PIL.Image`` of this frame.

        Any ``**kwargs`` are passed to :meth:`.VideoReformatter.reformat`.

        .. note:: PIL or Pillow must be installed.

        """
        from PIL import Image

        plane: VideoPlane = self.reformat(format="rgb24", **kwargs).planes[0]

        i_buf: cython.const[uint8_t][:] = plane
        i_pos: cython.size_t = 0
        i_stride: cython.size_t = plane.line_size

        o_pos: cython.size_t = 0
        o_stride: cython.size_t = plane.width * 3
        o_size: cython.size_t = plane.height * o_stride
        o_buf: bytearray = bytearray(o_size)

        while o_pos < o_size:
            o_buf[o_pos : o_pos + o_stride] = i_buf[i_pos : i_pos + o_stride]
            i_pos += i_stride
            o_pos += o_stride

        return Image.frombytes(
            "RGB", (plane.width, plane.height), bytes(o_buf), "raw", "RGB", 0, 1
        )

    def to_ndarray(self, channel_last=False, **kwargs):
        """Get a numpy array of this frame.

        Any ``**kwargs`` are passed to :meth:`.VideoReformatter.reformat`.

        The array returned is generally of dimension (height, width, channels).

        :param bool channel_last: If True, the shape of array will be
            (height, width, channels) rather than (channels, height, width) for
            the "yuv444p" and "yuvj444p" formats.

        .. note:: Numpy must be installed.

        .. note:: For formats which return an array of ``uint16``, ``float16`` or ``float32``,
            the samples will be in the system's native byte order.

        .. note:: For ``pal8``, an ``(image, palette)`` tuple will be returned,
            with the palette being in ARGB (PyAV will swap bytes if needed).

        .. note:: For ``gbrp`` formats, channels are flipped to RGB order.

        """
        if self.ptr.hw_frames_ctx and "format" not in kwargs:
            frames_ctx: cython.pointer[lib.AVHWFramesContext] = cython.cast(
                cython.pointer[lib.AVHWFramesContext], self.ptr.hw_frames_ctx.data
            )
            kwargs = dict(kwargs)
            kwargs["format"] = get_video_format(
                frames_ctx.sw_format, self.ptr.width, self.ptr.height
            ).name

        frame: VideoFrame = self.reformat(**kwargs)
        if frame.ptr.hw_frames_ctx:
            raise ValueError("Cannot convert a hardware frame to numpy directly.")

        import numpy as np

        # check size
        format_name = frame.format.name
        height, width = frame.ptr.height, frame.ptr.width
        planes = frame.planes
        if format_name in {"yuv420p", "yuvj420p", "yuyv422", "yuv422p10le", "yuv422p"}:
            assert width % 2 == 0, "the width has to be even for this pixel format"
            assert height % 2 == 0, "the height has to be even for this pixel format"

        # cases planes are simply concatenated in shape (height, width, channels)
        if format_name in _np_pix_fmt_dtypes:
            itemsize, dtype = _np_pix_fmt_dtypes[format_name]
            if len(planes) == 1:  # shortcut, avoid memory copy
                array = useful_array(planes[0], itemsize, dtype).reshape(
                    height, width, -1
                )
            else:  # general case
                array = np.empty((height, width, len(planes)), dtype=dtype)
                for i, plane in enumerate(planes):
                    array[:, :, i] = useful_array(plane, itemsize, dtype).reshape(
                        height, width
                    )
            array = byteswap_array(array, format_name.endswith("be"))
            if array.shape[2] == 1:  # skip last channel for gray images
                return array.squeeze(2)
            if format_name.startswith("gbr"):  # gbr -> rgb
                array[:, :, :3] = array[:, :, [2, 0, 1]]
            if not channel_last and format_name in {"yuv444p", "yuvj444p"}:
                array = np.moveaxis(array, 2, 0)
            return array

        # special cases
        if format_name in {"yuv420p", "yuvj420p", "yuv422p"}:
            return np.hstack(
                [
                    useful_array(planes[0]),
                    useful_array(planes[1]),
                    useful_array(planes[2]),
                ]
            ).reshape(-1, width)
        if format_name == "yuv422p10le":
            # Read planes as uint16 at their original width
            y = useful_array(planes[0], 2, "uint16").reshape(height, width)
            u = useful_array(planes[1], 2, "uint16").reshape(height, width // 2)
            v = useful_array(planes[2], 2, "uint16").reshape(height, width // 2)

            # Double the width of U and V by repeating each value
            u_full = np.repeat(u, 2, axis=1)
            v_full = np.repeat(v, 2, axis=1)
            if channel_last:
                return np.stack([y, u_full, v_full], axis=2)
            return np.stack([y, u_full, v_full], axis=0)
        if format_name == "pal8":
            image = useful_array(planes[0]).reshape(height, width)
            palette = (
                np.frombuffer(planes[1], "i4")
                .astype(">i4")
                .reshape(-1, 1)
                .view(np.uint8)
            )
            return image, palette
        if format_name == "nv12":
            return np.hstack(
                [useful_array(planes[0]), useful_array(planes[1], 2)]
            ).reshape(-1, width)

        raise ValueError(
            f"Conversion to numpy array with format `{format_name}` is not yet supported"
        )

    def set_image(self, img):
        """
        Update content from a ``PIL.Image``.
        """
        if img.mode != "RGB":
            img = img.convert("RGB")

        copy_array_to_plane(img, self.planes[0], 3)

    @staticmethod
    def from_image(img):
        """
        Construct a frame from a ``PIL.Image``.
        """
        frame: VideoFrame = VideoFrame(img.size[0], img.size[1], "rgb24")
        frame.set_image(img)

        return frame

    @staticmethod
    def from_numpy_buffer(array, format="rgb24", width=0):
        """
        Construct a frame from a numpy buffer.

        :param int width: optional width of actual image, if different from the array width.

        .. note:: For formats which expect an array of ``uint16``, ``float16`` or ``float32``,
            the samples must be in the system's native byte order.

        .. note:: for ``gbrp`` formats, channels are assumed to be given in RGB order.

        .. note:: For formats where width of the array is not the same as the width of the image,
        for example with yuv420p images the UV rows at the bottom have padding bytes in the middle of the
        row as well as at the end. To cope with these, callers need to be able to pass the actual width.
        """
        import numpy as np

        height = array.shape[0]
        if not width:
            width = array.shape[1]

        if format in {"rgb24", "bgr24"}:
            check_ndarray(array, "uint8", 3)
            check_ndarray_shape(array, array.shape[2] == 3)
            if array.strides[1:] != (3, 1):
                raise ValueError("provided array does not have C_CONTIGUOUS rows")
            linesizes = (array.strides[0],)
        elif format in {"rgb48le", "rgb48be", "bgr48le", "bgr48be"}:
            check_ndarray(array, "uint16", 3)
            check_ndarray_shape(array, array.shape[2] == 3)
            if array.strides[1:] != (6, 2):
                raise ValueError("provided array does not have C_CONTIGUOUS rows")
            linesizes = (array.strides[0],)
        elif format in {"rgbf32le", "rgbf32be"}:
            check_ndarray(array, "float32", 3)
            check_ndarray_shape(array, array.shape[2] == 3)
            if array.strides[1:] != (12, 4):
                raise ValueError("provided array does not have C_CONTIGUOUS rows")
            linesizes = (array.strides[0],)
        elif format in {"rgba", "bgra", "argb", "abgr"}:
            check_ndarray(array, "uint8", 3)
            check_ndarray_shape(array, array.shape[2] == 4)
            if array.strides[1:] != (4, 1):
                raise ValueError("provided array does not have C_CONTIGUOUS rows")
            linesizes = (array.strides[0],)
        elif format in {"rgba64le", "rgba64be", "bgra64le", "bgra64be"}:
            check_ndarray(array, "uint16", 3)
            check_ndarray_shape(array, array.shape[2] == 4)
            if array.strides[1:] != (8, 2):
                raise ValueError("provided array does not have C_CONTIGUOUS rows")
            linesizes = (array.strides[0],)
        elif format in {"rgbaf16le", "rgbaf16be"}:
            check_ndarray(array, "float16", 3)
            check_ndarray_shape(array, array.shape[2] == 4)
            if array.strides[1:] != (8, 2):
                raise ValueError("provided array does not have C_CONTIGUOUS rows")
            linesizes = (array.strides[0],)
        elif format in {"rgbaf32le", "rgbaf32be"}:
            check_ndarray(array, "float32", 3)
            check_ndarray_shape(array, array.shape[2] == 4)
            if array.strides[1:] != (16, 4):
                raise ValueError("provided array does not have C_CONTIGUOUS rows")
            linesizes = (array.strides[0],)
        elif format in {
            "gray",
            "gray8",
            "rgb8",
            "bgr8",
            "bayer_bggr8",
            "bayer_gbrg8",
            "bayer_grbg8",
            "bayer_rggb8",
        }:
            check_ndarray(array, "uint8", 2)
            if array.strides[1] != 1:
                raise ValueError("provided array does not have C_CONTIGUOUS rows")
            linesizes = (array.strides[0],)
        elif format in {
            "gray9be",
            "gray9le",
            "gray10be",
            "gray10le",
            "gray12be",
            "gray12le",
            "gray14be",
            "gray14le",
            "gray16be",
            "gray16le",
            "bayer_bggr16be",
            "bayer_bggr16le",
            "bayer_gbrg16be",
            "bayer_gbrg16le",
            "bayer_grbg16be",
            "bayer_grbg16le",
            "bayer_rggb16be",
            "bayer_rggb16le",
        }:
            check_ndarray(array, "uint16", 2)
            if array.strides[1] != 2:
                raise ValueError("provided array does not have C_CONTIGUOUS rows")
            linesizes = (array.strides[0],)
        elif format in {"grayf32le", "grayf32be"}:
            check_ndarray(array, "float32", 2)
            if array.strides[1] != 4:
                raise ValueError("provided array does not have C_CONTIGUOUS rows")
            linesizes = (array.strides[0],)
        elif format in {"gbrp"}:
            check_ndarray(array, "uint8", 3)
            check_ndarray_shape(array, array.shape[2] == 3)
            if array.strides[1:] != (3, 1):
                raise ValueError("provided array does not have C_CONTIGUOUS rows")
            linesizes = (
                array.strides[0] // 3,
                array.strides[0] // 3,
                array.strides[0] // 3,
            )
        elif format in {
            "gbrp9be",
            "gbrp9le",
            "gbrp10be",
            "gbrp10le",
            "gbrp12be",
            "gbrp12le",
            "gbrp14be",
            "gbrp14le",
            "gbrp16be",
            "gbrp16le",
        }:
            check_ndarray(array, "uint16", 3)
            check_ndarray_shape(array, array.shape[2] == 3)
            if array.strides[1:] != (6, 2):
                raise ValueError("provided array does not have C_CONTIGUOUS rows")
            linesizes = (
                array.strides[0] // 3,
                array.strides[0] // 3,
                array.strides[0] // 3,
            )
        elif format in {"gbrpf32be", "gbrpf32le"}:
            check_ndarray(array, "float32", 3)
            check_ndarray_shape(array, array.shape[2] == 3)
            if array.strides[1:] != (12, 4):
                raise ValueError("provided array does not have C_CONTIGUOUS rows")
            linesizes = (
                array.strides[0] // 3,
                array.strides[0] // 3,
                array.strides[0] // 3,
            )
        elif format in {"gbrap"}:
            check_ndarray(array, "uint8", 3)
            check_ndarray_shape(array, array.shape[2] == 4)
            if array.strides[1:] != (4, 1):
                raise ValueError("provided array does not have C_CONTIGUOUS rows")
            linesizes = (
                array.strides[0] // 4,
                array.strides[0] // 4,
                array.strides[0] // 4,
                array.strides[0] // 4,
            )
        elif format in {
            "gbrap10be",
            "gbrap10le",
            "gbrap12be",
            "gbrap12le",
            "gbrap14be",
            "gbrap14le",
            "gbrap16be",
            "gbrap16le",
        }:
            check_ndarray(array, "uint16", 3)
            check_ndarray_shape(array, array.shape[2] == 4)
            if array.strides[1:] != (8, 2):
                raise ValueError("provided array does not have C_CONTIGUOUS rows")
            linesizes = (
                array.strides[0] // 4,
                array.strides[0] // 4,
                array.strides[0] // 4,
                array.strides[0] // 4,
            )
        elif format in {"gbrapf32be", "gbrapf32le"}:
            check_ndarray(array, "float32", 3)
            check_ndarray_shape(array, array.shape[2] == 4)
            if array.strides[1:] != (16, 4):
                raise ValueError("provided array does not have C_CONTIGUOUS rows")
            linesizes = (
                array.strides[0] // 4,
                array.strides[0] // 4,
                array.strides[0] // 4,
                array.strides[0] // 4,
            )
        elif format in {"yuv420p", "yuvj420p", "nv12"}:
            check_ndarray(array, "uint8", 2)
            check_ndarray_shape(array, array.shape[0] % 3 == 0)
            check_ndarray_shape(array, array.shape[1] % 2 == 0)
            height = height // 6 * 4
            if array.strides[1] != 1:
                raise ValueError("provided array does not have C_CONTIGUOUS rows")
            if format in {"yuv420p", "yuvj420p"}:
                # For YUV420 planar formats, the UV plane stride is always half the Y stride.
                linesizes = (
                    array.strides[0],
                    array.strides[0] // 2,
                    array.strides[0] // 2,
                )
            else:
                # Planes where U and V are interleaved have the same stride as Y.
                linesizes = (array.strides[0], array.strides[0])
        else:
            raise ValueError(
                f"Conversion from numpy array with format `{format}` is not yet supported"
            )

        if format.startswith("gbrap"):  # rgba -> gbra
            array = np.ascontiguousarray(np.moveaxis(array[..., [1, 2, 0, 3]], -1, 0))
        elif format.startswith("gbrp"):  # rgb -> gbr
            array = np.ascontiguousarray(np.moveaxis(array[..., [1, 2, 0]], -1, 0))

        frame = VideoFrame(_cinit_bypass_sentinel)
        frame._image_fill_pointers_numpy(array, width, height, linesizes, format)
        return frame

    def _image_fill_pointers_numpy(self, buffer, width, height, linesizes, format):
        # If you want to use the numpy notation, then you need to include the following lines at the top of the file:
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

        # Using buffer.ctypes.data helps avoid any kind of usage of the c-api from
        # numpy, which avoid the need to add numpy as a compile time dependency.

        c_data: cython.Py_ssize_t = buffer.ctypes.data
        c_ptr: cython.pointer[uint8_t] = cython.cast(cython.pointer[uint8_t], c_data)
        c_format: lib.AVPixelFormat = get_pix_fmt(format)
        lib.av_frame_unref(self.ptr)

        # Hold on to a reference for the numpy buffer so that it doesn't get accidentally garbage collected
        self.ptr.format = c_format
        self.ptr.width = width
        self.ptr.height = height
        for i, linesize in enumerate(linesizes):
            self.ptr.linesize[i] = linesize

        required = err_check(
            lib.av_image_fill_pointers(
                self.ptr.data,
                cython.cast(lib.AVPixelFormat, self.ptr.format),
                self.ptr.height,
                c_ptr,
                self.ptr.linesize,
            )
        )

        py_buf = cython.cast(object, buffer)
        Py_INCREF(py_buf)

        self.ptr.buf[0] = lib.av_buffer_create(
            c_ptr,
            required,
            _numpy_avbuffer_free,
            cython.cast(cython.p_void, py_buf),
            0,
        )
        if self.ptr.buf[0] == cython.NULL:
            Py_DECREF(py_buf)
            raise MemoryError("av_buffer_create failed")

        self._init_user_attributes()

    @staticmethod
    def from_ndarray(array, format="rgb24", channel_last=False):
        """
        Construct a frame from a numpy array.

        :param bool channel_last: If False (default), the shape for the yuv444p and yuvj444p
            is given by (channels, height, width) rather than (height, width, channels).

        .. note:: For formats which expect an array of ``uint16``, ``float16`` or ``float32``,
            the samples must be in the system's native byte order.

        .. note:: for ``pal8``, an ``(image, palette)`` pair must be passed. `palette` must
            have shape (256, 4) and is given in ARGB format (PyAV will swap bytes if needed).

        .. note:: for ``gbrp`` formats, channels are assumed to be given in RGB order.

        """
        import numpy as np

        # case layers are concatenated
        channels, itemsize, dtype = {
            "bayer_bggr16be": (1, 2, "uint16"),
            "bayer_bggr16le": (1, 2, "uint16"),
            "bayer_bggr8": (1, 1, "uint8"),
            "bayer_gbrg16be": (1, 2, "uint16"),
            "bayer_gbrg16le": (1, 2, "uint16"),
            "bayer_gbrg8": (1, 1, "uint8"),
            "bayer_grbg16be": (1, 2, "uint16"),
            "bayer_grbg16le": (1, 2, "uint16"),
            "bayer_grbg8": (1, 1, "uint8"),
            "bayer_rggb16be": (1, 2, "uint16"),
            "bayer_rggb16le": (1, 2, "uint16"),
            "bayer_rggb8": (1, 1, "uint8"),
            "bgr8": (1, 1, "uint8"),
            "gbrap": (4, 1, "uint8"),
            "gbrap10be": (4, 2, "uint16"),
            "gbrap10le": (4, 2, "uint16"),
            "gbrap12be": (4, 2, "uint16"),
            "gbrap12le": (4, 2, "uint16"),
            "gbrap14be": (4, 2, "uint16"),
            "gbrap14le": (4, 2, "uint16"),
            "gbrap16be": (4, 2, "uint16"),
            "gbrap16le": (4, 2, "uint16"),
            "gbrapf32be": (4, 4, "float32"),
            "gbrapf32le": (4, 4, "float32"),
            "gbrp": (3, 1, "uint8"),
            "gbrp10be": (3, 2, "uint16"),
            "gbrp10le": (3, 2, "uint16"),
            "gbrp12be": (3, 2, "uint16"),
            "gbrp12le": (3, 2, "uint16"),
            "gbrp14be": (3, 2, "uint16"),
            "gbrp14le": (3, 2, "uint16"),
            "gbrp16be": (3, 2, "uint16"),
            "gbrp16le": (3, 2, "uint16"),
            "gbrp9be": (3, 2, "uint16"),
            "gbrp9le": (3, 2, "uint16"),
            "gbrpf32be": (3, 4, "float32"),
            "gbrpf32le": (3, 4, "float32"),
            "gray": (1, 1, "uint8"),
            "gray10be": (1, 2, "uint16"),
            "gray10le": (1, 2, "uint16"),
            "gray12be": (1, 2, "uint16"),
            "gray12le": (1, 2, "uint16"),
            "gray14be": (1, 2, "uint16"),
            "gray14le": (1, 2, "uint16"),
            "gray16be": (1, 2, "uint16"),
            "gray16le": (1, 2, "uint16"),
            "gray8": (1, 1, "uint8"),
            "gray9be": (1, 2, "uint16"),
            "gray9le": (1, 2, "uint16"),
            "grayf32be": (1, 4, "float32"),
            "grayf32le": (1, 4, "float32"),
            "rgb8": (1, 1, "uint8"),
            "yuv444p": (3, 1, "uint8"),
            "yuv444p16be": (3, 2, "uint16"),
            "yuv444p16le": (3, 2, "uint16"),
            "yuva444p16be": (4, 2, "uint16"),
            "yuva444p16le": (4, 2, "uint16"),
            "yuvj444p": (3, 1, "uint8"),
        }.get(format, (None, None, None))
        if channels is not None:
            if array.ndim == 2:  # (height, width) -> (height, width, 1)
                array = array[:, :, None]
            check_ndarray(array, dtype, 3)
            if not channel_last and format in {"yuv444p", "yuvj444p"}:
                array = np.moveaxis(array, 0, 2)  # (channels, h, w) -> (h, w, channels)
            check_ndarray_shape(array, array.shape[2] == channels)
            array = byteswap_array(array, format.endswith("be"))
            frame = VideoFrame(array.shape[1], array.shape[0], format)
            if frame.format.name.startswith("gbr"):  # rgb -> gbr
                array = np.concatenate(
                    [  # not inplace to avoid bad surprises
                        array[:, :, 1:3],
                        array[:, :, 0:1],
                        array[:, :, 3:],
                    ],
                    axis=2,
                )
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
        elif format == "yuv422p":
            check_ndarray(array, "uint8", 2)
            check_ndarray_shape(array, array.shape[0] % 4 == 0)
            check_ndarray_shape(array, array.shape[1] % 2 == 0)

            frame = VideoFrame(array.shape[1], array.shape[0] // 2, format)
            u_start = frame.width * frame.height
            v_start = u_start + u_start // 2
            flat = array.reshape(-1)
            copy_array_to_plane(flat[0:u_start], frame.planes[0], 1)
            copy_array_to_plane(flat[u_start:v_start], frame.planes[1], 1)
            copy_array_to_plane(flat[v_start:], frame.planes[2], 1)
            return frame
        elif format == "yuv422p10le":
            if not isinstance(array, np.ndarray) or array.dtype != np.uint16:
                raise ValueError("Array must be uint16 type")

            # Convert to channel-first if needed
            if channel_last and array.shape[2] == 3:
                array = np.moveaxis(array, 2, 0)
            elif not (array.shape[0] == 3):
                raise ValueError(
                    "Array must have shape (3, height, width) or (height, width, 3)"
                )

            height, width = array.shape[1:]
            if width % 2 != 0 or height % 2 != 0:
                raise ValueError("Width and height must be even")

            frame = VideoFrame(width, height, format)
            copy_array_to_plane(array[0], frame.planes[0], 2)
            # Subsample U and V by taking every other column
            u = array[1, :, ::2].copy()  # Need copy to ensure C-contiguous
            v = array[2, :, ::2].copy()  # Need copy to ensure C-contiguous
            copy_array_to_plane(u, frame.planes[1], 2)
            copy_array_to_plane(v, frame.planes[2], 2)
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
        elif format in {"rgb48be", "rgb48le", "bgr48be", "bgr48le"}:
            check_ndarray(array, "uint16", 3)
            check_ndarray_shape(array, array.shape[2] == 3)
            frame = VideoFrame(array.shape[1], array.shape[0], format)
            copy_array_to_plane(
                byteswap_array(array, format.endswith("be")), frame.planes[0], 6
            )
            return frame
        elif format in {"rgbf32be", "rgbf32le"}:
            check_ndarray(array, "float32", 3)
            check_ndarray_shape(array, array.shape[2] == 3)
            frame = VideoFrame(array.shape[1], array.shape[0], format)
            copy_array_to_plane(
                byteswap_array(array, format.endswith("be")), frame.planes[0], 12
            )
            return frame
        elif format in {"rgba64be", "rgba64le", "bgra64be", "bgra64le"}:
            check_ndarray(array, "uint16", 3)
            check_ndarray_shape(array, array.shape[2] == 4)
            frame = VideoFrame(array.shape[1], array.shape[0], format)
            copy_array_to_plane(
                byteswap_array(array, format.endswith("be")), frame.planes[0], 8
            )
            return frame
        elif format in {"rgbaf16be", "rgbaf16le"}:
            check_ndarray(array, "float16", 3)
            check_ndarray_shape(array, array.shape[2] == 4)
            frame = VideoFrame(array.shape[1], array.shape[0], format)
            copy_array_to_plane(
                byteswap_array(array, format.endswith("be")), frame.planes[0], 8
            )
            return frame
        elif format in {"rgbaf32be", "rgbaf32le"}:
            check_ndarray(array, "float32", 3)
            check_ndarray_shape(array, array.shape[2] == 4)
            frame = VideoFrame(array.shape[1], array.shape[0], format)
            copy_array_to_plane(
                byteswap_array(array, format.endswith("be")), frame.planes[0], 16
            )
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
            raise ValueError(
                f"Conversion from numpy array with format `{format}` is not yet supported"
            )

        frame = VideoFrame(array.shape[1], array.shape[0], format)
        copy_array_to_plane(
            array, frame.planes[0], 1 if array.ndim == 2 else array.shape[2]
        )

        return frame

    @staticmethod
    def from_bytes(
        img_bytes: bytes,
        width: int,
        height: int,
        format="rgba",
        flip_horizontal=False,
        flip_vertical=False,
    ):
        frame = VideoFrame(width, height, format)
        if format == "rgba":
            copy_bytes_to_plane(
                img_bytes, frame.planes[0], 4, flip_horizontal, flip_vertical
            )
        elif format in {
            "bayer_bggr8",
            "bayer_rggb8",
            "bayer_gbrg8",
            "bayer_grbg8",
            "bayer_bggr16le",
            "bayer_rggb16le",
            "bayer_gbrg16le",
            "bayer_grbg16le",
            "bayer_bggr16be",
            "bayer_rggb16be",
            "bayer_gbrg16be",
            "bayer_grbg16be",
        }:
            copy_bytes_to_plane(
                img_bytes,
                frame.planes[0],
                1 if format.endswith("8") else 2,
                flip_horizontal,
                flip_vertical,
            )
        else:
            raise NotImplementedError(f"Format '{format}' is not supported.")
        return frame

    @staticmethod
    def from_dlpack(
        planes,
        format: str = "nv12",
        width: int = 0,
        height: int = 0,
        stream=None,
        device_id: int | None = None,
        primary_ctx: bool = True,
        cuda_context=None,
    ):
        if not isinstance(planes, (tuple, list)):
            planes = (planes,)

        if len(planes) != 2:
            raise ValueError(
                "from_dlpack currently supports 2-plane formats only (nv12/p010le/p016le)"
            )

        sw_fmt: lib.AVPixelFormat = get_pix_fmt(format)
        nv12 = get_pix_fmt(b"nv12")
        p010le = get_pix_fmt(b"p010le")
        p016le = get_pix_fmt(b"p016le")

        if sw_fmt not in (nv12, p010le, p016le):
            raise NotImplementedError("from_dlpack supports nv12, p010le, p016le only")

        expected_bits = 8 if sw_fmt == nv12 else 16
        itemsize = 1 if expected_bits == 8 else 2

        m0: cython.pointer[DLManagedTensor] = cython.NULL
        m1: cython.pointer[DLManagedTensor] = cython.NULL
        frame: VideoFrame = None

        try:
            m0 = _consume_dlpack(planes[0], stream)
            m1 = _consume_dlpack(planes[1], stream)

            dev_type0 = m0.dl_tensor.device_type
            dev_type1 = m1.dl_tensor.device_type
            if dev_type0 != dev_type1:
                raise ValueError("plane tensors must have the same device_type")
            if dev_type0 not in (kCuda, kCPU):
                raise NotImplementedError(
                    "only CPU and CUDA DLPack tensors are supported"
                )

            dev0 = m0.dl_tensor.device_id
            dev1 = m1.dl_tensor.device_id
            if dev0 != dev1:
                raise ValueError("plane tensors must be on the same CUDA device")
            if dev_type0 == kCuda:
                if device_id is None:
                    device_id = dev0
                elif device_id != dev0:
                    raise ValueError(
                        "device_id does not match the DLPack tensor device_id"
                    )
            else:
                if device_id not in (None, 0):
                    raise ValueError("device_id must be 0 for CPU tensors")
                device_id = 0
            if dev_type0 == kCPU and (dev0 != 0 or dev1 != 0):
                raise ValueError("CPU DLPack tensors must have device_id == 0")

            if (
                m0.dl_tensor.dtype.code != 1
                or m0.dl_tensor.dtype.bits != expected_bits
                or m0.dl_tensor.dtype.lanes != 1
            ):
                raise TypeError("unexpected dtype for plane 0")
            if (
                m1.dl_tensor.dtype.code != 1
                or m1.dl_tensor.dtype.bits != expected_bits
                or m1.dl_tensor.dtype.lanes != 1
            ):
                raise TypeError("unexpected dtype for plane 1")

            if m0.dl_tensor.ndim != 2:
                raise ValueError("plane 0 must be 2D (H, W)")

            y_h = cython.cast(int64_t, m0.dl_tensor.shape[0])
            y_w = cython.cast(int64_t, m0.dl_tensor.shape[1])

            if width == 0 and height == 0:
                width = cython.cast(int, y_w)
                height = cython.cast(int, y_h)
            elif width == 0 or height == 0:
                raise ValueError("either specify both width/height or neither")
            else:
                if y_w != width or y_h != height:
                    raise ValueError("plane 0 shape does not match width/height")

            if width % 2 or height % 2:
                raise ValueError("width/height must be even for nv12/p010le/p016le")

            if m0.dl_tensor.strides != cython.NULL:
                if m0.dl_tensor.strides[1] != 1:
                    raise ValueError("plane 0 must be contiguous in the last dimension")
                y_pitch_elems = cython.cast(int64_t, m0.dl_tensor.strides[0])
            else:
                y_pitch_elems = cython.cast(int64_t, width)

            y_linesize = cython.cast(int, y_pitch_elems * itemsize)
            y_size = cython.cast(int, y_linesize * height)

            uv_ndim = m1.dl_tensor.ndim
            uv_h_expected = height // 2

            if uv_ndim == 2:
                uv_h = cython.cast(int, m1.dl_tensor.shape[0])
                uv_w = cython.cast(int, m1.dl_tensor.shape[1])
                if uv_h != uv_h_expected or uv_w != width:
                    raise ValueError("plane 1 must have shape (H/2, W) for 2D UV")
                if m1.dl_tensor.strides != cython.NULL:
                    if m1.dl_tensor.strides[1] != 1:
                        raise ValueError(
                            "plane 1 must be contiguous in the last dimension"
                        )
                    uv_pitch_elems = cython.cast(int64_t, m1.dl_tensor.strides[0])
                else:
                    uv_pitch_elems = cython.cast(int64_t, uv_w)
            elif uv_ndim == 3:
                uv_h = cython.cast(int, m1.dl_tensor.shape[0])
                uv_w2 = cython.cast(int, m1.dl_tensor.shape[1])
                uv_c = cython.cast(int, m1.dl_tensor.shape[2])
                if uv_h != uv_h_expected or uv_w2 != (width // 2) or uv_c != 2:
                    raise ValueError("plane 1 must have shape (H/2, W/2, 2) for 3D UV")
                if m1.dl_tensor.strides != cython.NULL:
                    if m1.dl_tensor.strides[2] != 1 or m1.dl_tensor.strides[1] != 2:
                        raise ValueError(
                            "unexpected UV plane strides for (H/2, W/2, 2)"
                        )
                    uv_pitch_elems = cython.cast(int64_t, m1.dl_tensor.strides[0])
                else:
                    uv_pitch_elems = cython.cast(int64_t, width)
            else:
                raise ValueError("plane 1 must be 2D or 3D")

            uv_linesize = cython.cast(int, uv_pitch_elems * itemsize)
            uv_size = cython.cast(int, uv_linesize * (height // 2))

            frame = alloc_video_frame()
            frame.ptr.width = width
            frame.ptr.height = height
            if dev_type0 == kCuda:
                ctx: CudaContext
                frames_ref: cython.pointer[lib.AVBufferRef]
                if cuda_context is None:
                    ctx = CudaContext(device_id=device_id, primary_ctx=primary_ctx)
                else:
                    if not isinstance(cuda_context, CudaContext):
                        raise TypeError("cuda_context must be a CudaContext")
                    if int(cuda_context.device_id) != int(device_id):
                        raise ValueError(
                            "cuda_context.device_id does not match the DLPack tensor device_id"
                        )
                    if bool(cuda_context.primary_ctx) != bool(primary_ctx):
                        raise ValueError(
                            "cuda_context.primary_ctx does not match primary_ctx"
                        )
                    ctx = cython.cast(CudaContext, cuda_context)

                frames_ref = ctx.get_frames_ctx(sw_fmt, width, height)
                frame.ptr.format = get_pix_fmt(b"cuda")
                frame.ptr.hw_frames_ctx = frames_ref
                frame._device_id = device_id
                frame._cuda_ctx = ctx
            else:
                frame.ptr.format = sw_fmt

            y_ptr = cython.cast(
                cython.pointer[uint8_t], m0.dl_tensor.data
            ) + cython.cast(cython.size_t, m0.dl_tensor.byte_offset)
            uv_ptr = cython.cast(
                cython.pointer[uint8_t], m1.dl_tensor.data
            ) + cython.cast(cython.size_t, m1.dl_tensor.byte_offset)

            frame.ptr.buf[0] = lib.av_buffer_create(
                y_ptr, y_size, _dlpack_avbuffer_free, cython.cast(cython.p_void, m0), 0
            )
            if frame.ptr.buf[0] == cython.NULL:
                raise MemoryError("av_buffer_create failed for plane 0")
            frame.ptr.data[0] = y_ptr
            frame.ptr.linesize[0] = y_linesize
            m0 = cython.NULL

            frame.ptr.buf[1] = lib.av_buffer_create(
                uv_ptr,
                uv_size,
                _dlpack_avbuffer_free,
                cython.cast(cython.p_void, m1),
                0,
            )
            if frame.ptr.buf[1] == cython.NULL:
                raise MemoryError("av_buffer_create failed for plane 1")
            frame.ptr.data[1] = uv_ptr
            frame.ptr.linesize[1] = uv_linesize
            m1 = cython.NULL

            frame._init_user_attributes()
            return frame

        except Exception:
            if frame is not None:
                lib.av_frame_unref(frame.ptr)
            if m0 != cython.NULL:
                m0.deleter(m0)
            if m1 != cython.NULL:
                m1.deleter(m1)
            raise
