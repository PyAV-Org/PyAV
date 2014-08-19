from fractions import Fraction

from .common import asset, av, TestCase


class TestVideoProbe(TestCase):
    def setUp(self):
        self.file = av.open(asset('320x240x4.mov'))

    def test_container_probing(self):
        self.assertEqual(self.file.size, 150484)
        self.assertEqual(str(self.file.format), "<av.ContainerFormat 'mov,mp4,m4a,3gp,3g2,mj2'>")
        self.assertEqual(self.file.format.name, 'mov,mp4,m4a,3gp,3g2,mj2')
        self.assertEqual(self.file.format.long_name, "QuickTime / MOV")
        self.assertEqual(self.file.duration, 4000000L)
        self.assertEqual(float(self.file.duration) / av.time_base, 4.0)
        self.assertEqual(self.file.bit_rate, 300968)
        self.assertEqual(len(self.file.streams), 1)
        self.assertEqual(self.file.start_time, 0L)
        self.assertEqual(
            self.file.metadata,
            {'major_brand': 'qt  ', 'encoder': 'Lavf55.48.101', 'compatible_brands': 'qt  ', 'minor_version': '512'})

    def test_stream_probing(self):
        stream = self.file.streams[0]
        self.assertEqual(stream.index, 0)
        self.assertEqual(stream.type, 'video')
        self.assertEqual(stream.name, 'mpeg4')
        self.assertEqual(stream.long_name, 'MPEG-4 part 2')
        self.assertEqual(stream.sample_aspect_ratio, Fraction(1, 1))
        self.assertEqual(stream.gop_size, 12)
        self.assertEqual(stream.format.name, 'yuv420p')
        self.assertFalse(stream.has_b_frames)
        self.assertEqual(stream.guessed_rate, Fraction(24, 1))
        self.assertEqual(stream.average_rate, Fraction(24, 1))


class TestAudioProbe(TestCase):
    def setUp(self):
        self.file = av.open(asset('1KHz.wav'))

    def test_container_probing(self):
        self.assertEqual(str(self.file.format), "<av.ContainerFormat 'wav'>")
        self.assertEqual(self.file.format.name, 'wav')
        self.assertEqual(self.file.format.long_name, "WAV / WAVE (Waveform Audio)")
        self.assertEqual(self.file.duration, 4000000L)
        self.assertEqual(float(self.file.duration) / av.time_base, 4.0)
        self.assertEqual(self.file.bit_rate, 1536088)
        self.assertEqual(len(self.file.streams), 1)
        self.assertEqual(self.file.start_time, -9223372036854775808L)
        self.assertEqual(self.file.metadata, {})

    def test_stream_probing(self):
        stream = self.file.streams[0]
        self.assertEqual(stream.index, 0)
        self.assertEqual(stream.type, 'audio')
        self.assertEqual(stream.name, 'pcm_s16le')
        self.assertEqual(stream.long_name, 'PCM signed 16-bit little-endian')
        self.assertEqual(stream.channels, 2)
        self.assertEqual(stream.layout.name, 'stereo')
        self.assertEqual(stream.rate, 48000)
        self.assertEqual(stream.format.name, 's16')
        self.assertEqual(stream.format.bits, 16)
