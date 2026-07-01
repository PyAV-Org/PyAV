from enum import IntEnum, IntFlag

import cython
import cython.cimports.libav as lib
from cython.cimports.av.error import err_check
from cython.cimports.av.video.format import VideoFormat, get_pix_fmt
from cython.cimports.av.video.frame import alloc_video_frame


class Interpolation(IntFlag):
    FAST_BILINEAR: "Fast bilinear" = SWS_FAST_BILINEAR
    BILINEAR: "Bilinear" = SWS_BILINEAR
    BICUBIC: "2-tap cubic B-spline" = SWS_BICUBIC
    X: "Experimental" = SWS_X
    POINT: "Nearest neighbor / point" = SWS_POINT
    AREA: "Area averaging" = SWS_AREA
    BICUBLIN: "Bicubic luma / Bilinear chroma" = SWS_BICUBLIN
    GAUSS: "Gaussian approximation" = SWS_GAUSS
    SINC: "Unwindowed Sinc" = SWS_SINC
    LANCZOS: "3-tap sinc/sinc" = SWS_LANCZOS
    SPLINE: "Unwindowed natural cubic spline" = SWS_SPLINE
    PRINT_INFO: "Emit verbose scaler info to the log" = SWS_PRINT_INFO
    FULL_CHR_H_INT: "Full chroma interpolation" = SWS_FULL_CHR_H_INT
    FULL_CHR_H_INP: "Full chroma input" = SWS_FULL_CHR_H_INP
    DIRECT_BGR: "Direct BGR" = SWS_DIRECT_BGR
    ACCURATE_RND: "Accurate rounding" = SWS_ACCURATE_RND
    BITEXACT: "Bit-exact output" = SWS_BITEXACT
    ERROR_DIFFUSION: "Error diffusion dither" = SWS_ERROR_DIFFUSION


class Colorspace(IntEnum):
    ITU709 = SWS_CS_ITU709
    FCC = SWS_CS_FCC
    ITU601 = SWS_CS_ITU601
    ITU624 = SWS_CS_ITU624
    SMPTE170M = SWS_CS_SMPTE170M
    SMPTE240M = SWS_CS_SMPTE240M
    DEFAULT = SWS_CS_DEFAULT
    BT2020 = SWS_CS_BT2020
    # Lowercase for b/c.
    itu709 = SWS_CS_ITU709
    fcc = SWS_CS_FCC
    itu601 = SWS_CS_ITU601
    itu624 = SWS_CS_ITU624
    smpte170m = SWS_CS_SMPTE170M
    smpte240m = SWS_CS_SMPTE240M
    default = SWS_CS_DEFAULT
    bt2020 = SWS_CS_BT2020


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
@cython.inline
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


@cython.cfunc
@cython.inline
def _resolve_format(format: object, default: lib.AVPixelFormat) -> lib.AVPixelFormat:
    if format is None:
        return default
    if isinstance(format, VideoFormat):
        return cython.cast(VideoFormat, format).pix_fmt
    return get_pix_fmt(format)


@cython.cfunc
def _set_frame_colorspace(
    frame: cython.pointer(lib.AVFrame),
    colorspace: cython.int,
    color_range: cython.int,
):
    """Set AVFrame colorspace/range from SWS_CS_* and AVColorRange values."""
    if color_range != lib.AVCOL_RANGE_UNSPECIFIED:
        frame.color_range = cython.cast(lib.AVColorRange, color_range)
    # Mapping from SWS_CS_* (swscale colorspace) to AVColorSpace (frame metadata).
    # Note: SWS_CS_ITU601, SWS_CS_ITU624, SWS_CS_SMPTE170M, and SWS_CS_DEFAULT all have
    # the same value (5), so we map 5 -> AVCOL_SPC_SMPTE170M as the most common case.
    # SWS_CS_DEFAULT is handled specially by not setting frame metadata.
    if colorspace == SWS_CS_ITU709:
        frame.colorspace = lib.AVCOL_SPC_BT709
    elif colorspace == SWS_CS_FCC:
        frame.colorspace = lib.AVCOL_SPC_FCC
    elif colorspace == SWS_CS_ITU601:
        frame.colorspace = lib.AVCOL_SPC_SMPTE170M
    elif colorspace == SWS_CS_SMPTE240M:
        frame.colorspace = lib.AVCOL_SPC_SMPTE240M
    elif colorspace == SWS_CS_BT2020:
        frame.colorspace = lib.AVCOL_SPC_BT2020_NCL


@cython.final
@cython.cclass
class VideoReformatter:
    """An object for reformatting size and pixel format of :class:`.VideoFrame`.

    It is most efficient to have a reformatter object for each set of parameters
    you will use as calling :meth:`reformat` will reconfigure the internal object.

    """

    def __dealloc__(self):
        with cython.nogil:
            sws_free_context(cython.address(self.ptr))

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
        threads=None,
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
        :param interpolation: The scaling algorithm to use, or ``None`` for ``BILINEAR``.
            Option flags such as ``ACCURATE_RND`` or ``BITEXACT`` may be combined with
            the algorithm using ``|``, e.g. ``Interpolation.BILINEAR | Interpolation.ACCURATE_RND``.
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
        :param int threads: How many threads to use for scaling, or ``0`` for automatic
            selection based on the number of available CPUs. Defaults to ``0`` (auto).

        """
        c_dst_format = _resolve_format(format, frame.format.pix_fmt)
        c_src_colorspace = _resolve_enum_value(
            src_colorspace, Colorspace, frame.ptr.colorspace
        )
        c_dst_colorspace = _resolve_enum_value(
            dst_colorspace, Colorspace, frame.ptr.colorspace
        )
        c_interpolation = _resolve_enum_value(
            interpolation, Interpolation, SWS_BILINEAR
        )
        c_src_color_range = _resolve_enum_value(src_color_range, ColorRange, 0)
        c_dst_color_range = _resolve_enum_value(dst_color_range, ColorRange, 0)
        # Default to UNSPECIFIED (not the source's value) so that a transfer /
        # primaries conversion is only performed when explicitly requested. See
        # _reformat for why.
        c_dst_color_trc = _resolve_enum_value(
            dst_color_trc, ColorTrc, lib.AVCOL_TRC_UNSPECIFIED
        )
        c_dst_color_primaries = _resolve_enum_value(
            dst_color_primaries, ColorPrimaries, lib.AVCOL_PRI_UNSPECIFIED
        )
        c_threads: cython.int = threads if threads is not None else 0
        c_width: cython.int = width if width is not None else frame.ptr.width
        c_height: cython.int = height if height is not None else frame.ptr.height

        return self._reformat(
            frame,
            c_width,
            c_height,
            c_dst_format,
            c_src_colorspace,
            c_dst_colorspace,
            c_interpolation,
            c_src_color_range,
            c_dst_color_range,
            c_dst_color_trc,
            c_dst_color_primaries,
            c_threads,
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
        dst_color_trc: cython.int,
        dst_color_primaries: cython.int,
        threads: cython.int,
    ):
        if frame.ptr.hw_frames_ctx:
            frame_sw = alloc_video_frame()
            err_check(lib.av_hwframe_transfer_data(frame_sw.ptr, frame.ptr, 0))
            frame_sw._copy_internal_attributes(frame, data_layout=False)
            frame_sw._init_user_attributes()
            frame = frame_sw

        new_frame: VideoFrame = alloc_video_frame()
        new_frame._copy_internal_attributes(frame, data_layout=False)
        new_frame.ptr.format = dst_format
        new_frame.ptr.width = width
        new_frame.ptr.height = height

        # A transfer-characteristic / primaries conversion is opt-in. Unlike the
        # pre-17.0 sws_scale, sws_scale_frame inspects color_trc/color_primaries
        # and rejects RESERVED (and other unsupported) values with EOPNOTSUPP,
        # which regressed plain reformats of e.g. VP9 / NVDEC frames (#2208). So
        # only feed these fields to swscale when the caller explicitly requested a
        # destination value; otherwise neutralize them for the scale (as the old
        # sws_scale effectively did) while still preserving the source's tags on
        # the returned frame's metadata.
        convert_trc: cython.bint = dst_color_trc != lib.AVCOL_TRC_UNSPECIFIED
        convert_primaries: cython.bint = (
            dst_color_primaries != lib.AVCOL_PRI_UNSPECIFIED
        )
        frame_src_color_trc: lib.AVColorTransferCharacteristic = frame.ptr.color_trc
        frame_src_color_primaries: lib.AVColorPrimaries = frame.ptr.color_primaries

        if convert_trc:
            new_frame.ptr.color_trc = cython.cast(
                lib.AVColorTransferCharacteristic, dst_color_trc
            )
        else:
            frame.ptr.color_trc = lib.AVCOL_TRC_UNSPECIFIED
            new_frame.ptr.color_trc = lib.AVCOL_TRC_UNSPECIFIED

        if convert_primaries:
            new_frame.ptr.color_primaries = cython.cast(
                lib.AVColorPrimaries, dst_color_primaries
            )
        else:
            frame.ptr.color_primaries = lib.AVCOL_PRI_UNSPECIFIED
            new_frame.ptr.color_primaries = lib.AVCOL_PRI_UNSPECIFIED

        # Translate source and destination colorspace/range from SWS_CS_* to AVCOL_*
        # so sws_is_noop and sws_scale_frame understand them
        frame_src_colorspace: lib.AVColorSpace = frame.ptr.colorspace
        frame_src_color_range: lib.AVColorRange = frame.ptr.color_range
        _set_frame_colorspace(frame.ptr, src_colorspace, src_color_range)
        _set_frame_colorspace(new_frame.ptr, dst_colorspace, dst_color_range)

        # Shortcut if sws_scale_frame would be a no-op
        is_noop: cython.bint = sws_is_noop(new_frame.ptr, frame.ptr) != 0
        if is_noop:
            # Restore source frame metadata to avoid side effects
            frame.ptr.colorspace = frame_src_colorspace
            frame.ptr.color_range = frame_src_color_range
            frame.ptr.color_trc = frame_src_color_trc
            frame.ptr.color_primaries = frame_src_color_primaries
            return frame

        if self.ptr == cython.NULL:
            self.ptr = sws_alloc_context()
            if self.ptr == cython.NULL:
                raise MemoryError("Could not allocate SwsContext")
        self.ptr.threads = threads
        self.ptr.flags = cython.cast(cython.uint, interpolation)

        # Allocate frame buffers and perform the conversion
        new_frame._init(dst_format, width, height)
        with cython.nogil:
            ret = sws_scale_frame(self.ptr, new_frame.ptr, frame.ptr)

        # Restore source frame metadata to avoid side effects
        frame.ptr.colorspace = frame_src_colorspace
        frame.ptr.color_range = frame_src_color_range
        frame.ptr.color_trc = frame_src_color_trc
        frame.ptr.color_primaries = frame_src_color_primaries

        # Preserve the source's transfer/primaries on the output when no explicit
        # conversion was requested (the scale ran with neutralized tags).
        if not convert_trc:
            new_frame.ptr.color_trc = frame_src_color_trc
        if not convert_primaries:
            new_frame.ptr.color_primaries = frame_src_color_primaries

        err_check(ret)

        return new_frame
