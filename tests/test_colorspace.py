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
