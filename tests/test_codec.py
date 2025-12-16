import pytest

from av import AudioFormat, Codec, VideoFormat, codecs_available
from av.codec import find_best_pix_fmt_of_list
from av.codec.codec import UnknownCodecError


def test_codec_bogus() -> None:
    with pytest.raises(UnknownCodecError):
        Codec("bogus123")
    with pytest.raises(UnknownCodecError):
        Codec("bogus123", "w")


def test_codec_mpeg4_decoder() -> None:
    c = Codec("mpeg4")

    assert c.name == "mpeg4"
    assert c.long_name == "MPEG-4 part 2"
    assert c.type == "video"
    assert c.id in (12, 13)
    assert c.is_decoder
    assert not c.is_encoder
    assert c.delay

    assert c.audio_formats is None and c.audio_rates is None

    # formats = c.video_formats
    # assert formats
    # assert isinstance(formats[0], VideoFormat)
    # assert any(f.name == "yuv420p" for f in formats)

    assert c.frame_rates is None


def test_codec_mpeg4_encoder() -> None:
    c = Codec("mpeg4", "w")
    assert c.name == "mpeg4"
    assert c.long_name == "MPEG-4 part 2"
    assert c.type == "video"
    assert c.id in (12, 13)
    assert c.is_encoder
    assert not c.is_decoder
    assert c.delay

    assert c.audio_formats is None and c.audio_rates is None

    formats = c.video_formats
    assert formats
    assert isinstance(formats[0], VideoFormat)
    assert any(f.name == "yuv420p" for f in formats)
    assert c.frame_rates is None


def test_codec_opus_decoder() -> None:
    c = Codec("opus")

    assert c.name == "opus"
    assert c.long_name == "Opus"
    assert c.type == "audio"
    assert c.is_decoder
    assert not c.is_encoder
    assert c.delay

    assert c.audio_formats is None and c.audio_rates is None
    assert c.video_formats is None and c.frame_rates is None


def test_codec_opus_encoder() -> None:
    c = Codec("opus", "w")
    assert c.name in ("opus", "libopus")
    assert c.canonical_name == "opus"
    assert c.long_name in ("Opus", "libopus Opus")
    assert c.type == "audio"
    assert c.is_encoder
    assert not c.is_decoder
    assert c.delay

    # audio
    formats = c.audio_formats
    assert formats
    assert isinstance(formats[0], AudioFormat)
    assert any(f.name in ("flt", "fltp") for f in formats)

    assert c.audio_rates is not None
    assert 48000 in c.audio_rates

    assert c.video_formats is None and c.frame_rates is None


def test_codecs_available() -> None:
    assert codecs_available


def test_find_best_pix_fmt_of_list_empty() -> None:
    best, loss = find_best_pix_fmt_of_list([], "rgb24")
    assert best is None
    assert loss == 0


@pytest.mark.parametrize(
    "pix_fmts,src_pix_fmt,expected_best",
    [
        (["rgb24", "yuv420p"], "rgb24", "rgb24"),
        (["rgb24"], "yuv420p", "rgb24"),
        (["yuv420p"], "rgb24", "yuv420p"),
        ([VideoFormat("yuv420p")], VideoFormat("rgb24"), "yuv420p"),
        (
            ["yuv420p", "yuv444p", "gray", "rgb24", "rgba", "bgra", "yuyv422"],
            "rgba",
            "rgba",
        ),
    ],
)
def test_find_best_pix_fmt_of_list_best(pix_fmts, src_pix_fmt, expected_best) -> None:
    best, loss = find_best_pix_fmt_of_list(pix_fmts, src_pix_fmt)
    assert best is not None
    assert best.name == expected_best
    assert isinstance(loss, int)


@pytest.mark.parametrize(
    "pix_fmts,src_pix_fmt",
    [
        (["__unknown_pix_fmt"], "rgb24"),
        (["rgb24"], "__unknown_pix_fmt"),
    ],
)
def test_find_best_pix_fmt_of_list_unknown_pix_fmt(pix_fmts, src_pix_fmt) -> None:
    with pytest.raises(ValueError, match="not a pixel format"):
        find_best_pix_fmt_of_list(pix_fmts, src_pix_fmt)


@pytest.mark.parametrize(
    "pix_fmts,src_pix_fmt",
    [
        (["rgb24", "bgr24", "gray", "yuv420p", "yuv444p", "yuyv422"], "nv12"),
        (["yuv420p", "yuv444p", "gray", "yuv420p"], "rgb24"),
        (["rgb24", "rgba", "bgra", "rgb24", "gray"], "yuv420p"),
    ],
)
def test_find_best_pix_fmt_of_list_picks_from_list(pix_fmts, src_pix_fmt) -> None:
    best, loss = find_best_pix_fmt_of_list(pix_fmts, src_pix_fmt)
    assert best is not None
    assert best.name in set(pix_fmts)
    assert isinstance(loss, int)


def test_find_best_pix_fmt_of_list_alpha_loss_flagged_when_used() -> None:
    best, loss = find_best_pix_fmt_of_list(["rgb24"], "rgba", has_alpha=True)
    assert best is not None
    assert best.name == "rgb24"
    assert loss != 0
