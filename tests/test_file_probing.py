from __future__ import division

from fractions import Fraction
import sys

from .common import fate_suite, av, TestCase

try:
    long
except NameError:
    long = int


class TestAudioProbe(TestCase):
    def setUp(self):
        self.file = av.open(fate_suite('aac/latm_stereo_to_51.ts'))

    def test_container_probing(self):
        self.assertEqual(str(self.file.format), "<av.ContainerFormat 'mpegts'>")
        self.assertEqual(self.file.format.name, 'mpegts')
        self.assertEqual(self.file.format.long_name, "MPEG-TS (MPEG-2 Transport Stream)")
        self.assertEqual(self.file.size, 207740)

        # This is a little odd, but on OS X with FFmpeg we get a different value.
        self.assertIn(self.file.bit_rate, (269558, 270494))

        self.assertEqual(len(self.file.streams), 1)
        self.assertEqual(self.file.start_time, long(1400000))
        self.assertEqual(self.file.metadata, {})

    def test_stream_probing(self):
        stream = self.file.streams[0]
        self.assertEqual(stream.index, 0)
        self.assertEqual(stream.type, 'audio')
        self.assertEqual(stream.name, 'aac_latm')
        self.assertEqual(stream.long_name, 'AAC LATM (Advanced Audio Coding LATM syntax)')
        self.assertEqual(stream.bit_rate, None)
        self.assertEqual(stream.max_bit_rate, None)
        self.assertEqual(stream.channels, 2)
        self.assertEqual(stream.layout.name, 'stereo')
        self.assertEqual(stream.rate, 48000)
        self.assertEqual(stream.format.name, 'fltp')
        self.assertEqual(stream.format.bits, 32)
        self.assertEqual(stream.language, "eng")


class TestVideoProbe(TestCase):
    
    def setUp(self):
        self.file = av.open(fate_suite('mpeg2/mpeg2_field_encoding.ts'))

    def test_container_probing(self):
        self.assertEqual(str(self.file.format), "<av.ContainerFormat 'mpegts'>")
        self.assertEqual(self.file.format.name, 'mpegts')
        self.assertEqual(self.file.format.long_name, "MPEG-TS (MPEG-2 Transport Stream)")
        self.assertEqual(self.file.size, 800000)

        # This is a little odd, but on OS X with FFmpeg we get a different value.
        self.assertIn(self.file.duration, (1620000, 1580000))

        self.assertEqual(self.file.bit_rate, 8 * self.file.size * av.time_base // self.file.duration)
        self.assertEqual(len(self.file.streams), 1)
        self.assertEqual(self.file.start_time, long(22953408322))
        self.assertEqual(self.file.size, 800000)
        self.assertEqual(self.file.metadata, {})

    def test_stream_probing(self):
        stream = self.file.streams[0]
        self.assertEqual(stream.index, 0)
        self.assertEqual(stream.type, 'video')
        self.assertEqual(stream.name, 'mpeg2video')
        self.assertEqual(stream.long_name, 'MPEG-2 video')
        self.assertEqual(stream.profile, 'Simple')

        # Libav is able to return a bit-rate for this file, but ffmpeg doesn't,
        # so have to rely on rc_max_rate.
        try:
            self.assertEqual(stream.bit_rate, None)
            self.assertEqual(stream.max_bit_rate, 3364800)
        except AssertionError:
            self.assertEqual(stream.bit_rate, 3364800)

        self.assertEqual(stream.sample_aspect_ratio, Fraction(16, 15))
        self.assertEqual(stream.display_aspect_ratio, Fraction(4, 3))
        self.assertEqual(stream.gop_size, 12)
        self.assertEqual(stream.format.name, 'yuv420p')
        self.assertFalse(stream.has_b_frames)
        self.assertEqual(stream.average_rate, Fraction(25, 1))
        self.assertEqual(stream.width, 720)
        self.assertEqual(stream.height, 576)

        # For some reason, these behave differently on OS X (@mikeboers) and
        # Ubuntu (Travis). We think it is FFmpeg, but haven't been able to
        # confirm.
        self.assertIn(stream.coded_width, (720, 0))
        self.assertIn(stream.coded_height, (576, 0))
