from av import AudioFormat, Codec, VideoFormat, codecs_available
from av.codec.codec import UnknownCodecError

from .common import TestCase


class TestCodecs(TestCase):
    def test_codec_bogus(self) -> None:
        with self.assertRaises(UnknownCodecError):
            Codec("bogus123")
        with self.assertRaises(UnknownCodecError):
            Codec("bogus123", "w")

    def test_codec_mpeg4_decoder(self) -> None:
        c = Codec("mpeg4")

        assert c.name == "mpeg4"
        assert c.long_name == "MPEG-4 part 2"
        assert c.type == "video"
        assert c.id in (12, 13)
        assert c.is_decoder
        assert not c.is_encoder
        assert c.delay

        # audio
        assert c.audio_formats is None
        assert c.audio_rates is None

        # video
        # formats = c.video_formats
        # assert formats
        # assert isinstance(formats[0], VideoFormat)
        # assert any(f.name == "yuv420p" for f in formats)

        assert c.frame_rates is None

    def test_codec_mpeg4_encoder(self) -> None:
        c = Codec("mpeg4", "w")
        assert c.name == "mpeg4"
        assert c.long_name == "MPEG-4 part 2"
        assert c.type == "video"
        assert c.id in (12, 13)
        assert c.is_encoder
        assert not c.is_decoder
        assert c.delay

        # audio
        assert c.audio_formats is None
        assert c.audio_rates is None

        # video
        formats = c.video_formats
        assert formats
        assert isinstance(formats[0], VideoFormat)
        assert any(f.name == "yuv420p" for f in formats)
        assert c.frame_rates is None

    def test_codec_opus_decoder(self) -> None:
        c = Codec("opus")

        self.assertEqual(c.name, "opus")
        self.assertEqual(c.long_name, "Opus")
        assert c.type == "audio"
        assert c.is_decoder
        assert not c.is_encoder
        assert c.delay

        # audio
        assert c.audio_formats is None
        assert c.audio_rates is None

        # video
        assert c.video_formats is None
        assert c.frame_rates is None

    def test_codec_opus_encoder(self) -> None:
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

        # video
        assert c.video_formats is None
        assert c.frame_rates is None

    def test_codecs_available(self) -> None:
        assert codecs_available
