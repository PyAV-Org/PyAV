from .common import *
from av.codec import Codec
from av.video.format import VideoFormat

class TestCodecs(TestCase):

    def test_codec_mpeg4(self):

        c = Codec('mpeg4')

        self.assertEqual(c.name, 'mpeg4')
        self.assertEqual(c.long_name, 'MPEG-4 part 2')
        self.assertEqual(c.type, 'video')
        self.assertEqual(c.id, 13)
        self.assertTrue(c.is_decoder)
        self.assertFalse(c.is_encoder)

        formats = c.video_formats
        self.assertTrue(formats)
        self.assertIsInstance(formats[0], VideoFormat)
        self.assertTrue(any(f.name == 'yuv420p' for f in formats))

        c = Codec('mpeg4', 'w')
        self.assertEqual(c.name, 'mpeg4')
        self.assertEqual(c.long_name, 'MPEG-4 part 2')
        self.assertEqual(c.type, 'video')
        self.assertEqual(c.id, 13)
        self.assertTrue(c.is_encoder)
        self.assertFalse(c.is_decoder)
