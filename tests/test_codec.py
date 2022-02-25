import unittest

from av import AudioFormat, Codec, VideoFormat, codecs_available
from av.codec.codec import UnknownCodecError

from .common import TestCase


# some older ffmpeg versions have no native opus encoder
try:
    opus_c = Codec("opus", "w")
    opus_encoder_missing = False
except UnknownCodecError:
    opus_encoder_missing = True


class TestCodecs(TestCase):
    def test_codec_bogus(self):
        with self.assertRaises(UnknownCodecError):
            Codec("bogus123")
        with self.assertRaises(UnknownCodecError):
            Codec("bogus123", "w")

    def test_codec_mpeg4_decoder(self):
        c = Codec("mpeg4")

        self.assertEqual(c.name, "mpeg4")
        self.assertEqual(c.long_name, "MPEG-4 part 2")
        self.assertEqual(c.type, "video")
        self.assertIn(c.id, (12, 13))
        self.assertTrue(c.is_decoder)
        self.assertFalse(c.is_encoder)

        # audio
        self.assertIsNone(c.audio_formats)
        self.assertIsNone(c.audio_rates)

        # video
        formats = c.video_formats
        self.assertTrue(formats)
        self.assertIsInstance(formats[0], VideoFormat)
        self.assertTrue(any(f.name == "yuv420p" for f in formats))

        self.assertIsNone(c.frame_rates)

    def test_codec_mpeg4_encoder(self):
        c = Codec("mpeg4", "w")
        self.assertEqual(c.name, "mpeg4")
        self.assertEqual(c.long_name, "MPEG-4 part 2")
        self.assertEqual(c.type, "video")
        self.assertIn(c.id, (12, 13))
        self.assertTrue(c.is_encoder)
        self.assertFalse(c.is_decoder)

        # audio
        self.assertIsNone(c.audio_formats)
        self.assertIsNone(c.audio_rates)

        # video
        formats = c.video_formats
        self.assertTrue(formats)
        self.assertIsInstance(formats[0], VideoFormat)
        self.assertTrue(any(f.name == "yuv420p" for f in formats))

        self.assertIsNone(c.frame_rates)

    def test_codec_opus_decoder(self):
        c = Codec("opus")

        self.assertEqual(c.name, "opus")
        self.assertEqual(c.long_name, "Opus")
        self.assertEqual(c.type, "audio")
        self.assertTrue(c.is_decoder)
        self.assertFalse(c.is_encoder)

        # audio
        self.assertIsNone(c.audio_formats)
        self.assertIsNone(c.audio_rates)

        # video
        self.assertIsNone(c.video_formats)
        self.assertIsNone(c.frame_rates)

    @unittest.skipIf(opus_encoder_missing, "Opus encoder is not available")
    def test_codec_opus_encoder(self):
        c = Codec("opus", "w")
        self.assertIn(c.name, ("opus", "libopus"))
        self.assertIn(c.long_name, ("Opus", "libopus Opus"))
        self.assertEqual(c.type, "audio")
        self.assertTrue(c.is_encoder)
        self.assertFalse(c.is_decoder)

        # audio
        formats = c.audio_formats
        self.assertTrue(formats)
        self.assertIsInstance(formats[0], AudioFormat)
        self.assertTrue(any(f.name in ["flt", "fltp"] for f in formats))

        self.assertIsNotNone(c.audio_rates)
        self.assertIn(48000, c.audio_rates)

        # video
        self.assertIsNone(c.video_formats)
        self.assertIsNone(c.frame_rates)

    def test_codecs_available(self):
        self.assertTrue(codecs_available)
