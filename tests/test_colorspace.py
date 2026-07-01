import pytest

import av
from av.video.reformatter import (
    ColorPrimaries,
    ColorRange,
    Colorspace,
    ColorTrc,
)

from .common import fate_suite


def test_penguin_joke() -> None:
    container = av.open(
        fate_suite("amv/MTV_high_res_320x240_sample_Penguin_Joke_MTV_from_WMV.amv")
    )
    stream = container.streams.video[0]

    assert stream.codec_context.color_range == 2
    assert stream.codec_context.color_range == ColorRange.JPEG

    assert stream.codec_context.color_primaries == 2
    assert stream.codec_context.color_trc == 2

    assert stream.codec_context.colorspace == 5
    assert stream.codec_context.colorspace == Colorspace.ITU601

    for frame in container.decode(stream):
        assert frame.color_range == ColorRange.JPEG  # a.k.a "pc"
        assert frame.colorspace == Colorspace.ITU601
        return


def test_sky_timelapse() -> None:
    container = av.open(
        av.datasets.curated("pexels/time-lapse-video-of-night-sky-857195.mp4")
    )
    stream = container.streams.video[0]

    assert stream.disposition == av.stream.Disposition.default

    assert stream.codec_context.color_range == 1
    assert stream.codec_context.color_range == ColorRange.MPEG
    assert stream.codec_context.color_primaries == 1
    assert stream.codec_context.color_trc == 1
    assert stream.codec_context.colorspace == 1


def test_frame_color_trc_property() -> None:
    frame = av.VideoFrame(width=64, height=64, format="rgb24")
    assert frame.color_trc == ColorTrc.UNSPECIFIED

    frame.color_trc = ColorTrc.IEC61966_2_4
    assert frame.color_trc == ColorTrc.IEC61966_2_4

    frame.color_trc = ColorTrc.BT709
    assert frame.color_trc == ColorTrc.BT709


def test_frame_color_primaries_property() -> None:
    frame = av.VideoFrame(width=64, height=64, format="rgb24")
    assert frame.color_primaries == ColorPrimaries.UNSPECIFIED

    frame.color_primaries = ColorPrimaries.BT709
    assert frame.color_primaries == ColorPrimaries.BT709
    assert frame.color_primaries == 1  # AVCOL_PRI_BT709


def test_reformat_dst_color_trc() -> None:
    # Reformat a frame and tag it with sRGB transfer characteristic.
    frame = av.VideoFrame(width=64, height=64, format="yuv420p")
    rgb = frame.reformat(
        format="rgb24",
        dst_colorspace=Colorspace.ITU709,
        dst_color_trc=ColorTrc.IEC61966_2_4,
    )
    assert rgb.format.name == "rgb24"
    assert rgb.colorspace == Colorspace.ITU709
    assert rgb.color_trc == ColorTrc.IEC61966_2_4


def test_reformat_dst_color_primaries() -> None:
    frame = av.VideoFrame(width=64, height=64, format="yuv420p")
    rgb = frame.reformat(
        format="rgb24",
        dst_color_primaries=ColorPrimaries.BT709,
    )
    assert rgb.color_primaries == ColorPrimaries.BT709


def test_reformat_preserves_color_trc() -> None:
    # When dst_color_trc is not specified, the source frame's value is preserved.
    frame = av.VideoFrame(width=64, height=64, format="yuv420p")
    frame.color_trc = ColorTrc.BT709
    rgb = frame.reformat(format="rgb24")
    assert rgb.color_trc == ColorTrc.BT709


def test_reformat_preserves_color_primaries() -> None:
    # When dst_color_primaries is not specified, the source frame's value is preserved.
    frame = av.VideoFrame(width=64, height=64, format="yuv420p")
    frame.color_primaries = ColorPrimaries.BT709
    rgb = frame.reformat(format="rgb24")
    assert rgb.color_primaries == ColorPrimaries.BT709


@pytest.mark.parametrize(
    ("colorspace", "expected"),
    [
        (Colorspace.ITU709, Colorspace.ITU709),
        (Colorspace.FCC, Colorspace.FCC),
        (Colorspace.ITU601, 6),  # AVCOL_SPC_SMPTE170M
        (Colorspace.SMPTE240M, Colorspace.SMPTE240M),
        (Colorspace.BT2020, Colorspace.BT2020),
    ],
)
def test_reformat_dst_colorspace_metadata(
    colorspace: Colorspace, expected: Colorspace | int
) -> None:
    frame = av.VideoFrame(width=64, height=64, format="yuv420p")
    rgb = frame.reformat(format="rgb24", dst_colorspace=colorspace)
    assert rgb.colorspace == expected


# RESERVED0 (0) and RESERVED (3) primaries/transfer values, plus a couple of
# transfer functions swscale can't handle (LOG / LOG_SQRT). Real VP9 and NVDEC
# streams routinely tag frames with these. sws_scale_frame (used since 17.0.0)
# validates these fields and rejects them with EOPNOTSUPP, which regressed a
# plain reformat/to_ndarray to "rgb24" (#2208). The pre-17.0 sws_scale ignored
# them, and a transfer/primaries conversion should stay opt-in.
@pytest.mark.parametrize(
    ("color_primaries", "color_trc"),
    [
        (3, 3),  # RESERVED / RESERVED
        (0, 0),  # RESERVED0 / RESERVED0
        (3, 2),  # reserved primaries only
        (2, 3),  # reserved transfer only
        (2, 9),  # AVCOL_TRC_LOG (unsupported by swscale)
        (2, 10),  # AVCOL_TRC_LOG_SQRT (unsupported by swscale)
    ],
)
def test_reformat_unsupported_color_metadata(
    color_primaries: int, color_trc: int
) -> None:
    frame = av.VideoFrame(width=64, height=64, format="yuv420p")
    frame.colorspace = Colorspace.ITU709
    frame.color_primaries = color_primaries
    frame.color_trc = color_trc

    # Neither of these should raise OSError(EOPNOTSUPP).
    rgb = frame.reformat(format="rgb24")
    assert rgb.format.name == "rgb24"
    array = frame.to_ndarray(format="rgb24")
    assert array.shape == (64, 64, 3)

    # The reformat must not mutate the source frame's metadata.
    assert frame.color_primaries == color_primaries
    assert frame.color_trc == color_trc

    # The BT.709 matrix is still applied even though the transfer/primaries are
    # unsupported: a neutral gray must stay gray.
    gray = av.VideoFrame(width=64, height=64, format="yuv420p")
    gray.colorspace = Colorspace.ITU709
    gray.color_primaries = color_primaries
    gray.color_trc = color_trc
    for plane, value in zip(gray.planes, (128, 128, 128)):
        plane.update(bytes([value]) * plane.buffer_size)
    out = gray.to_ndarray(format="rgb24")
    assert out.min() == out.max() == out[0, 0, 0]
