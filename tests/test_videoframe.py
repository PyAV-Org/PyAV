from .common import *


class TestVideoFrameBasics(TestCase):

    def test_null_constructor(self):
        frame = VideoFrame()
        self.assertEqual(frame.width, 0)
        self.assertEqual(frame.height, 0)
        self.assertEqual(frame.format, 'yuv420p')

    def test_manual_constructor(self):
        frame = VideoFrame(640, 480, 'rgb24')
        self.assertEqual(frame.width, 640)
        self.assertEqual(frame.height, 480)
        self.assertEqual(frame.format, 'rgb24')
        self.assertEqual(frame.buffer_size, 640 * 480 * 3)


class TestVideoFrameTransforms(TestCase):

    def setUp(self):
        self.lenna = Image.open(asset('lenna.png'))
        self.width, self.height = self.lenna.size

    def test_lena_roundtrip(self):
        frame = VideoFrame(self.width, self.height, 'rgb24')
        frame.update_from_string(self.lenna.tostring())
        img = frame.to_image()
        img.save(self.sandboxed('roundtrip.jpg'))
        self.assertImagesAlmostEqual(self.lenna, img)

