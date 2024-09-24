import pytest

from av import AudioFormat, Codec, VideoFormat, codecs_available
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
