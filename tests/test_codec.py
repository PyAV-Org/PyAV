from .common import *
from av.codec import Codec, Encoder, Decoder
from av.video.format import VideoFormat

class TestCodecs(TestCase):

    def test_codec_mpeg4(self):

        for cls in Encoder, Decoder:
            c = cls('mpeg4')

            self.assertEqual(c.name, 'mpeg4')
            self.assertEqual(c.long_name, 'MPEG-4 part 2')
            self.assertEqual(c.type, 'video')
            self.assertEqual(c.id, 13)
            self.assertEqual(c.is_encoder, cls is Encoder)
            self.assertEqual(c.is_decoder, cls is Decoder)

            formats = c.video_formats
            self.assertTrue(formats)
            self.assertIsInstance(formats[0], VideoFormat)
            self.assertTrue(any(f.name == 'yuv420p' for f in formats))
