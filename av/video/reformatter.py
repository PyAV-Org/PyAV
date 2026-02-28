from enum import IntEnum

import cython
from cython.cimports.av.error import err_check
from cython.cimports.av.video.format import VideoFormat
from cython.cimports.av.video.frame import alloc_video_frame


class Interpolation(IntEnum):
    FAST_BILINEAR: "Fast bilinear" = SWS_FAST_BILINEAR
    BILINEAR: "Bilinear" = SWS_BILINEAR
    BICUBIC: "Bicubic" = SWS_BICUBIC
    X: "Experimental" = SWS_X
    POINT: "Nearest neighbor / point" = SWS_POINT
    AREA: "Area averaging" = SWS_AREA
    BICUBLIN: "Luma bicubic / chroma bilinear" = SWS_BICUBLIN
    GAUSS: "Gaussian" = SWS_GAUSS
    SINC: "Sinc" = SWS_SINC
    LANCZOS: "Bicubic spline" = SWS_LANCZOS


class Colorspace(IntEnum):
    ITU709 = SWS_CS_ITU709
    FCC = SWS_CS_FCC
    ITU601 = SWS_CS_ITU601
    ITU624 = SWS_CS_ITU624
    SMPTE170M = SWS_CS_SMPTE170M
    SMPTE240M = SWS_CS_SMPTE240M
    DEFAULT = SWS_CS_DEFAULT
    # Lowercase for b/c.
    itu709 = SWS_CS_ITU709
    fcc = SWS_CS_FCC
    itu601 = SWS_CS_ITU601
    itu624 = SWS_CS_ITU624
    smpte170m = SWS_CS_SMPTE170M
    smpte240m = SWS_CS_SMPTE240M
    default = SWS_CS_DEFAULT


class ColorRange(IntEnum):
    UNSPECIFIED: "Unspecified" = lib.AVCOL_RANGE_UNSPECIFIED
    MPEG: "MPEG (limited) YUV range, 219*2^(n-8)" = lib.AVCOL_RANGE_MPEG
    JPEG: "JPEG (full) YUV range, 2^n-1" = lib.AVCOL_RANGE_JPEG
    NB: "Not part of ABI" = lib.AVCOL_RANGE_NB


class ColorTrc(IntEnum):
    """Transfer characteristic (gamma curve) of a video frame.

    Maps to FFmpeg's ``AVColorTransferCharacteristic``.
    """

    BT709: "BT.709" = lib.AVCOL_TRC_BT709
    UNSPECIFIED: "Unspecified" = lib.AVCOL_TRC_UNSPECIFIED
    GAMMA22: "Gamma 2.2 (BT.470M)" = lib.AVCOL_TRC_GAMMA22
    GAMMA28: "Gamma 2.8 (BT.470BG)" = lib.AVCOL_TRC_GAMMA28
    SMPTE170M: "SMPTE 170M" = lib.AVCOL_TRC_SMPTE170M
    SMPTE240M: "SMPTE 240M" = lib.AVCOL_TRC_SMPTE240M
    LINEAR: "Linear" = lib.AVCOL_TRC_LINEAR
    LOG: "Logarithmic (100:1 range)" = lib.AVCOL_TRC_LOG
    LOG_SQRT: "Logarithmic (100*sqrt(10):1 range)" = lib.AVCOL_TRC_LOG_SQRT
    IEC61966_2_4: "IEC 61966-2-4 (sRGB)" = lib.AVCOL_TRC_IEC61966_2_4
    BT1361_ECG: "BT.1361 extended colour gamut" = lib.AVCOL_TRC_BT1361_ECG
    IEC61966_2_1: "IEC 61966-2-1 (sYCC)" = lib.AVCOL_TRC_IEC61966_2_1
    BT2020_10: "BT.2020 10-bit" = lib.AVCOL_TRC_BT2020_10
    BT2020_12: "BT.2020 12-bit" = lib.AVCOL_TRC_BT2020_12
    SMPTE2084: "SMPTE 2084 (PQ, HDR10)" = lib.AVCOL_TRC_SMPTE2084
    SMPTE428: "SMPTE 428-1" = lib.AVCOL_TRC_SMPTE428
    ARIB_STD_B67: "ARIB STD-B67 (HLG)" = lib.AVCOL_TRC_ARIB_STD_B67


class ColorPrimaries(IntEnum):
    """Color primaries of a video frame.

    Maps to FFmpeg's ``AVColorPrimaries``.
    """

    BT709: "BT.709 / sRGB / sYCC" = lib.AVCOL_PRI_BT709
    UNSPECIFIED: "Unspecified" = lib.AVCOL_PRI_UNSPECIFIED
    BT470M: "BT.470M" = lib.AVCOL_PRI_BT470M
    BT470BG: "BT.470BG / BT.601-6 625" = lib.AVCOL_PRI_BT470BG
    SMPTE170M: "SMPTE 170M / BT.601-6 525" = lib.AVCOL_PRI_SMPTE170M
    SMPTE240M: "SMPTE 240M" = lib.AVCOL_PRI_SMPTE240M
    FILM: "Generic film (Illuminant C)" = lib.AVCOL_PRI_FILM
    BT2020: "BT.2020 / BT.2100" = lib.AVCOL_PRI_BT2020
    SMPTE428: "SMPTE 428-1 / XYZ" = lib.AVCOL_PRI_SMPTE428
    SMPTE431: "SMPTE 431-2 (DCI-P3)" = lib.AVCOL_PRI_SMPTE431
    SMPTE432: "SMPTE 432-1 (Display P3)" = lib.AVCOL_PRI_SMPTE432
    EBU3213: "EBU 3213-E / JEDEC P22" = lib.AVCOL_PRI_EBU3213


@cython.cfunc
def _resolve_enum_value(
    value: object, enum_class: object, default: cython.int
) -> cython.int:
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


# Mapping from SWS_CS_* (swscale colorspace) to AVColorSpace (frame metadata).
# Note: SWS_CS_ITU601, SWS_CS_ITU624, SWS_CS_SMPTE170M, and SWS_CS_DEFAULT all have
# the same value (5), so we map 5 -> AVCOL_SPC_SMPTE170M as the most common case.
# SWS_CS_DEFAULT is handled specially by not setting frame metadata.
_SWS_CS_TO_AVCOL_SPC = cython.declare(
    dict,
    {
        SWS_CS_ITU709: lib.AVCOL_SPC_BT709,
        SWS_CS_FCC: lib.AVCOL_SPC_FCC,
        SWS_CS_ITU601: lib.AVCOL_SPC_SMPTE170M,
        SWS_CS_SMPTE240M: lib.AVCOL_SPC_SMPTE240M,
    },
)


@cython.cclass
class VideoReformatter:
    """An object for reformatting size and pixel format of :class:`.VideoFrame`.

    It is most efficient to have a reformatter object for each set of parameters
    you will use as calling :meth:`reformat` will reconfigure the internal object.

    """

    def __dealloc__(self):
        with cython.nogil:
            sws_freeContext(self.ptr)

    def reformat(
        self,
        frame: VideoFrame,
        width=None,
        height=None,
        format=None,
        src_colorspace=None,
        dst_colorspace=None,
        interpolation=None,
        src_color_range=None,
        dst_color_range=None,
        dst_color_trc=None,
        dst_color_primaries=None,
    ):
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
        :type  src_color_range: :class:`ColorRange` or ``str``
        :param dst_color_range: Desired color range, or ``None`` for the ``UNSPECIFIED``.
        :type  dst_color_range: :class:`ColorRange` or ``str``
        :param dst_color_trc: Desired transfer characteristic to tag on the output frame,
            or ``None`` to preserve the source frame's value. This sets frame metadata only;
            it does not perform a pixel-level transfer function conversion.
        :type  dst_color_trc: :class:`ColorTrc` or ``int``
        :param dst_color_primaries: Desired color primaries to tag on the output frame,
            or ``None`` to preserve the source frame's value.
        :type  dst_color_primaries: :class:`ColorPrimaries` or ``int``

        """

        video_format: VideoFormat = VideoFormat(
            format if format is not None else frame.format
        )
        c_src_colorspace = _resolve_enum_value(
            src_colorspace, Colorspace, frame.colorspace
        )
        c_dst_colorspace = _resolve_enum_value(
            dst_colorspace, Colorspace, frame.colorspace
        )
        c_interpolation = _resolve_enum_value(
            interpolation, Interpolation, int(Interpolation.BILINEAR)
        )
        c_src_color_range = _resolve_enum_value(src_color_range, ColorRange, 0)
        c_dst_color_range = _resolve_enum_value(dst_color_range, ColorRange, 0)
        c_dst_color_trc = _resolve_enum_value(dst_color_trc, ColorTrc, 0)
        c_dst_color_primaries = _resolve_enum_value(
            dst_color_primaries, ColorPrimaries, 0
        )

        # Track whether user explicitly specified destination metadata
        set_dst_colorspace: cython.bint = dst_colorspace is not None
        set_dst_color_range: cython.bint = dst_color_range is not None
        set_dst_color_trc: cython.bint = dst_color_trc is not None
        set_dst_color_primaries: cython.bint = dst_color_primaries is not None

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
            set_dst_colorspace,
            set_dst_color_range,
            c_dst_color_trc,
            c_dst_color_primaries,
            set_dst_color_trc,
            set_dst_color_primaries,
        )

    @cython.cfunc
    def _reformat(
        self,
        frame: VideoFrame,
        width: cython.int,
        height: cython.int,
        dst_format: lib.AVPixelFormat,
        src_colorspace: cython.int,
        dst_colorspace: cython.int,
        interpolation: cython.int,
        src_color_range: cython.int,
        dst_color_range: cython.int,
        set_dst_colorspace: cython.bint,
        set_dst_color_range: cython.bint,
        dst_color_trc: cython.int,
        dst_color_primaries: cython.int,
        set_dst_color_trc: cython.bint,
        set_dst_color_primaries: cython.bint,
    ):
        if frame.ptr.format < 0:
            raise ValueError("Frame does not have format set.")

        # Save original values to set on the output frame (before swscale conversion)
        frame_dst_colorspace = dst_colorspace
        frame_dst_color_range = dst_color_range

        # The definition of color range in pixfmt.h and swscale.h is different.
        src_color_range = 1 if src_color_range == ColorRange.JPEG.value else 0
        dst_color_range = 1 if dst_color_range == ColorRange.JPEG.value else 0

        src_format = cython.cast(lib.AVPixelFormat, frame.ptr.format)

        # Shortcut!
        if frame.ptr.hw_frames_ctx:
            if (
                dst_format == src_format
                and width == frame.ptr.width
                and height == frame.ptr.height
                and dst_colorspace == src_colorspace
                and src_color_range == dst_color_range
                and not set_dst_color_trc
                and not set_dst_color_primaries
            ):
                return frame

            frame_sw = alloc_video_frame()
            err_check(lib.av_hwframe_transfer_data(frame_sw.ptr, frame.ptr, 0))
            frame_sw.pts = frame.pts
            frame_sw._init_user_attributes()
            frame = frame_sw
            src_format = cython.cast(lib.AVPixelFormat, frame.ptr.format)

        if (
            dst_format == src_format
            and width == frame.ptr.width
            and height == frame.ptr.height
            and dst_colorspace == src_colorspace
            and src_color_range == dst_color_range
            and not set_dst_color_trc
            and not set_dst_color_primaries
        ):
            return frame

        with cython.nogil:
            self.ptr = sws_getCachedContext(
                self.ptr,
                frame.ptr.width,
                frame.ptr.height,
                src_format,
                width,
                height,
                dst_format,
                interpolation,
                cython.NULL,
                cython.NULL,
                cython.NULL,
            )

        # We want to change the colorspace/color_range transforms.
        # We do that by grabbing all the current settings, changing a
        # couple, and setting them all. We need a lot of state here.
        inv_tbl: cython.p_int
        tbl: cython.p_int
        src_colorspace_range: cython.int
        dst_colorspace_range: cython.int
        brightness: cython.int
        contrast: cython.int
        saturation: cython.int

        if src_colorspace != dst_colorspace or src_color_range != dst_color_range:
            with cython.nogil:
                ret = sws_getColorspaceDetails(
                    self.ptr,
                    cython.address(inv_tbl),
                    cython.address(src_colorspace_range),
                    cython.address(tbl),
                    cython.address(dst_colorspace_range),
                    cython.address(brightness),
                    cython.address(contrast),
                    cython.address(saturation),
                )
            err_check(ret)

            with cython.nogil:
                # Grab the coefficients for the requested transforms.
                # The inv_table brings us to linear, and `tbl` to the new space.
                if src_colorspace != SWS_CS_DEFAULT:
                    inv_tbl = cython.cast(
                        cython.p_int, sws_getCoefficients(src_colorspace)
                    )
                if dst_colorspace != SWS_CS_DEFAULT:
                    tbl = cython.cast(cython.p_int, sws_getCoefficients(dst_colorspace))

                ret = sws_setColorspaceDetails(
                    self.ptr,
                    inv_tbl,
                    src_color_range,
                    tbl,
                    dst_color_range,
                    brightness,
                    contrast,
                    saturation,
                )
            err_check(ret)

        new_frame: VideoFrame = alloc_video_frame()
        new_frame._copy_internal_attributes(frame)
        new_frame._init(dst_format, width, height)

        # Set the colorspace and color_range on the output frame only if explicitly specified
        if set_dst_colorspace and frame_dst_colorspace in _SWS_CS_TO_AVCOL_SPC:
            new_frame.ptr.colorspace = cython.cast(
                lib.AVColorSpace, _SWS_CS_TO_AVCOL_SPC[frame_dst_colorspace]
            )
        if set_dst_color_range:
            new_frame.ptr.color_range = cython.cast(
                lib.AVColorRange, frame_dst_color_range
            )
        if set_dst_color_trc:
            new_frame.ptr.color_trc = cython.cast(
                lib.AVColorTransferCharacteristic, dst_color_trc
            )
        if set_dst_color_primaries:
            new_frame.ptr.color_primaries = cython.cast(
                lib.AVColorPrimaries, dst_color_primaries
            )

        with cython.nogil:
            sws_scale(
                self.ptr,
                cython.cast("const unsigned char *const *", frame.ptr.data),
                cython.cast("const int *", frame.ptr.linesize),
                0,  # slice Y
                frame.ptr.height,
                new_frame.ptr.data,
                new_frame.ptr.linesize,
            )

        return new_frame
