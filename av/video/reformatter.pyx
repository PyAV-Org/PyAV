cimport libav as lib
from libc.stdint cimport uint8_t

from av.error cimport err_check
from av.video.format cimport VideoFormat
from av.video.frame cimport alloc_video_frame

from enum import IntEnum


class Interpolation(IntEnum):
    FAST_BILINEAR: "Fast bilinear" = lib.SWS_FAST_BILINEAR
    BILINEAR: "Bilinear" = lib.SWS_BILINEAR
    BICUBIC: "Bicubic" = lib.SWS_BICUBIC
    X: "Experimental" = lib.SWS_X
    POINT: "Nearest neighbor / point" = lib.SWS_POINT
    AREA: "Area averaging" = lib.SWS_AREA
    BICUBLIN: "Luma bicubic / chroma bilinear" = lib.SWS_BICUBLIN
    GAUSS: "Gaussian" = lib.SWS_GAUSS
    SINC: "Sinc" = lib.SWS_SINC
    LANCZOS: "Bicubic spline" = lib.SWS_LANCZOS


class Colorspace(IntEnum):
    ITU709 = lib.SWS_CS_ITU709
    FCC = lib.SWS_CS_FCC
    ITU601 = lib.SWS_CS_ITU601
    ITU624 = lib.SWS_CS_ITU624
    SMPTE170M = lib.SWS_CS_SMPTE170M
    SMPTE240M = lib.SWS_CS_SMPTE240M
    DEFAULT = lib.SWS_CS_DEFAULT
    # Lowercase for b/c.
    itu709 = lib.SWS_CS_ITU709
    fcc = lib.SWS_CS_FCC
    itu601 = lib.SWS_CS_ITU601
    itu624 = lib.SWS_CS_ITU624
    smpte170m = lib.SWS_CS_SMPTE170M
    smpte240m = lib.SWS_CS_SMPTE240M
    default = lib.SWS_CS_DEFAULT

class ColorRange(IntEnum):
    UNSPECIFIED: "Unspecified" = lib.AVCOL_RANGE_UNSPECIFIED
    MPEG: "MPEG (limited) YUV range, 219*2^(n-8)" = lib.AVCOL_RANGE_MPEG
    JPEG: "JPEG (full) YUV range, 2^n-1" = lib.AVCOL_RANGE_JPEG
    NB: "Not part of ABI" = lib.AVCOL_RANGE_NB


def _resolve_enum_value(value, enum_class, default):
    # Helper function to resolve enum values from different input types.
    if value is None:
        return default
    if isinstance(value, enum_class):
        return value.value
    if isinstance(value, int):
        return value
    if isinstance(value, str):
        return enum_class[value].value
    raise ValueError(f"Cannot convert {value} to {enum_class.__name__}")


cdef class VideoReformatter:
    """An object for reformatting size and pixel format of :class:`.VideoFrame`.

    It is most efficient to have a reformatter object for each set of parameters
    you will use as calling :meth:`reformat` will reconfigure the internal object.

    """

    def __dealloc__(self):
        with nogil:
            lib.sws_freeContext(self.ptr)

    def reformat(self, VideoFrame frame not None, width=None, height=None,
                 format=None, src_colorspace=None, dst_colorspace=None,
                 interpolation=None, src_color_range=None,
                 dst_color_range=None):
        """Create a new :class:`VideoFrame` with the given width/height/format/colorspace.

        Returns the same frame untouched if nothing needs to be done to it.

        :param int width: New width, or ``None`` for the same width.
        :param int height: New height, or ``None`` for the same height.
        :param format: New format, or ``None`` for the same format.
        :type  format: :class:`.VideoFormat` or ``str``
        :param src_colorspace: Current colorspace, or ``None`` for the frame colorspace.
        :type  src_colorspace: :class:`Colorspace` or ``str``
        :param dst_colorspace: Desired colorspace, or ``None`` for the frame colorspace.
        :type  dst_colorspace: :class:`Colorspace` or ``str``
        :param interpolation: The interpolation method to use, or ``None`` for ``BILINEAR``.
        :type  interpolation: :class:`Interpolation` or ``str``
        :param src_color_range: Current color range, or ``None`` for the ``UNSPECIFIED``.
        :type  src_color_range: :class:`color range` or ``str``
        :param dst_color_range: Desired color range, or ``None`` for the ``UNSPECIFIED``.
        :type  dst_color_range: :class:`color range` or ``str``

        """

        cdef VideoFormat video_format = VideoFormat(format if format is not None else frame.format)

        cdef int c_src_colorspace = _resolve_enum_value(src_colorspace, Colorspace, frame.colorspace)
        cdef int c_dst_colorspace = _resolve_enum_value(dst_colorspace, Colorspace, frame.colorspace)
        cdef int c_interpolation = _resolve_enum_value(interpolation, Interpolation, int(Interpolation.BILINEAR))
        cdef int c_src_color_range = _resolve_enum_value(src_color_range, ColorRange, 0)
        cdef int c_dst_color_range = _resolve_enum_value(dst_color_range, ColorRange, 0)

        return self._reformat(
            frame,
            width or frame.ptr.width,
            height or frame.ptr.height,
            video_format.pix_fmt,
            c_src_colorspace,
            c_dst_colorspace,
            c_interpolation,
            c_src_color_range,
            c_dst_color_range,
        )

    cdef _reformat(self, VideoFrame frame, int width, int height,
                   lib.AVPixelFormat dst_format, int src_colorspace,
                   int dst_colorspace, int interpolation,
                   int src_color_range, int dst_color_range):

        if frame.ptr.format < 0:
            raise ValueError("Frame does not have format set.")

        # The definition of color range in pixfmt.h and swscale.h is different.
        src_color_range = 1 if src_color_range == ColorRange.JPEG.value else 0
        dst_color_range = 1 if dst_color_range == ColorRange.JPEG.value else 0

        cdef lib.AVPixelFormat src_format = <lib.AVPixelFormat> frame.ptr.format

        # Shortcut!
        if (
            dst_format == src_format and
            width == frame.ptr.width and
            height == frame.ptr.height and
            dst_colorspace == src_colorspace and
            src_color_range == dst_color_range
        ):
            return frame

        with nogil:
            self.ptr = lib.sws_getCachedContext(
                self.ptr,
                frame.ptr.width,
                frame.ptr.height,
                src_format,
                width,
                height,
                dst_format,
                interpolation,
                NULL,
                NULL,
                NULL
            )

        # We want to change the colorspace/color_range transforms.
        # We do that by grabbing all of the current settings, changing a
        # couple, and setting them all. We need a lot of state here.
        cdef const int *inv_tbl
        cdef const int *tbl
        cdef int src_colorspace_range, dst_colorspace_range
        cdef int brightness, contrast, saturation
        cdef int ret

        if src_colorspace != dst_colorspace or src_color_range != dst_color_range:
            with nogil:
                # Casts for const-ness, because Cython isn't expressive enough.
                ret = lib.sws_getColorspaceDetails(
                    self.ptr,
                    <int**>&inv_tbl,
                    &src_colorspace_range,
                    <int**>&tbl,
                    &dst_colorspace_range,
                    &brightness,
                    &contrast,
                    &saturation
                )

            err_check(ret)

            with nogil:
                # Grab the coefficients for the requested transforms.
                # The inv_table brings us to linear, and `tbl` to the new space.
                if src_colorspace != lib.SWS_CS_DEFAULT:
                    inv_tbl = lib.sws_getCoefficients(src_colorspace)
                if dst_colorspace != lib.SWS_CS_DEFAULT:
                    tbl = lib.sws_getCoefficients(dst_colorspace)

                # Apply!
                ret = lib.sws_setColorspaceDetails(
                    self.ptr,
                    inv_tbl,
                    src_color_range,
                    tbl,
                    dst_color_range,
                    brightness,
                    contrast,
                    saturation
                )

            err_check(ret)

        # Create a new VideoFrame.
        cdef VideoFrame new_frame = alloc_video_frame()
        new_frame._copy_internal_attributes(frame)
        new_frame._init(dst_format, width, height)

        # Finally, scale the image.
        with nogil:
            lib.sws_scale(
                self.ptr,
                # Cast for const-ness, because Cython isn't expressive enough.
                <const uint8_t**>frame.ptr.data,
                frame.ptr.linesize,
                0,  # slice Y
                frame.ptr.height,
                new_frame.ptr.data,
                new_frame.ptr.linesize,
            )

        return new_frame
