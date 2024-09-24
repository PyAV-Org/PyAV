import av
from av.video.reformatter import ColorRange, Colorspace

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

    assert stream.codec_context.color_range == 1
    assert stream.codec_context.color_range == ColorRange.MPEG
    assert stream.codec_context.color_primaries == 1
    assert stream.codec_context.color_trc == 1
    assert stream.codec_context.colorspace == 1
