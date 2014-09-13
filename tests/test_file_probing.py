from fractions import Fraction
import sys

from .common import asset, av, TestCase

try:
    long
except NameError:
    long = int


class TestAudioProbe(TestCase):
    def setUp(self):
        self.file = av.open(asset('latm_stereo_to_51.ts'))

    def test_container_probing(self):
        self.assertEqual(str(self.file.format), "<av.ContainerFormat 'mpegts'>")
        self.assertEqual(self.file.format.name, 'mpegts')
        self.assertEqual(self.file.format.long_name, "MPEG-TS (MPEG-2 Transport Stream)")
        self.assertEqual(self.file.bit_rate, 270494)
        self.assertEqual(len(self.file.streams), 1)
        self.assertEqual(self.file.start_time, long(1400000))
        self.assertEqual(self.file.size, 207740)
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
        self.file = av.open(asset('mpeg2_field_encoding.ts'))

    def test_container_probing(self):
        self.assertEqual(str(self.file.format), "<av.ContainerFormat 'mpegts'>")
        self.assertEqual(self.file.format.name, 'mpegts')
        self.assertEqual(self.file.format.long_name, "MPEG-TS (MPEG-2 Transport Stream)")
        self.assertEqual(self.file.duration, long(1580000))
        self.assertEqual(float(self.file.duration) / av.time_base, 1.58)
        self.assertEqual(self.file.bit_rate, 4050632)
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
        try:  # Libav is able to return a bit-rate for this file, but ffmpeg doesn't, so have to rely on rc_max_rate.
            self.assertEqual(stream.bit_rate, None)
            self.assertEqual(stream.max_bit_rate, 3364800)
        except AssertionError:
            self.assertEqual(stream.bit_rate, 3364800)
        self.assertEqual(stream.sample_aspect_ratio, Fraction(16, 15))
        self.assertEqual(stream.display_aspect_ratio, Fraction(4, 3))
        self.assertEqual(stream.gop_size, 12)
        self.assertEqual(stream.format.name, 'yuv420p')
        self.assertFalse(stream.has_b_frames)
        self.assertEqual(stream.guessed_rate, Fraction(25, 1))
        self.assertEqual(stream.average_rate, Fraction(25, 1))
        self.assertEqual(stream.width, 720)
        self.assertEqual(stream.height, 576)
        self.assertEqual(stream.coded_width, 720)
        self.assertEqual(stream.coded_height, 576)
