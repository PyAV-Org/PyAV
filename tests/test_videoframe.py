import warnings

from av import VideoFrame
from av.deprecation import AttributeRenamedWarning

from .common import fate_png, is_py3, Image, SkipTest, TestCase


class TestVideoFrameConstructors(TestCase):

    def test_null_constructor(self):
        frame = VideoFrame()
        self.assertEqual(frame.width, 0)
        self.assertEqual(frame.height, 0)
        self.assertEqual(frame.format.name, 'yuv420p')

    def test_manual_yuv_constructor(self):
        frame = VideoFrame(640, 480, 'yuv420p')
        self.assertEqual(frame.width, 640)
        self.assertEqual(frame.height, 480)
        self.assertEqual(frame.format.name, 'yuv420p')

    def test_manual_rgb_constructor(self):
        frame = VideoFrame(640, 480, 'rgb24')
        self.assertEqual(frame.width, 640)
        self.assertEqual(frame.height, 480)
        self.assertEqual(frame.format.name, 'rgb24')


class TestVideoFramePlanes(TestCase):

    def test_null_planes(self):
        frame = VideoFrame() # yuv420p
        self.assertEqual(len(frame.planes), 0)

    def test_yuv420p_planes(self):
        frame = VideoFrame(640, 480, 'yuv420p')
        self.assertEqual(len(frame.planes), 3)
        self.assertEqual(frame.planes[0].width, 640)
        self.assertEqual(frame.planes[0].height, 480)
        self.assertEqual(frame.planes[0].line_size, 640)
        self.assertEqual(frame.planes[0].buffer_size, 640 * 480)
        for i in range(1, 3):
            self.assertEqual(frame.planes[i].width, 320)
            self.assertEqual(frame.planes[i].height, 240)
            self.assertEqual(frame.planes[i].line_size, 320)
            self.assertEqual(frame.planes[i].buffer_size, 320 * 240)

    def test_rgb24_planes(self):
        frame = VideoFrame(640, 480, 'rgb24')
        self.assertEqual(len(frame.planes), 1)
        self.assertEqual(frame.planes[0].width, 640)
        self.assertEqual(frame.planes[0].height, 480)
        self.assertEqual(frame.planes[0].line_size, 640 * 3)
        self.assertEqual(frame.planes[0].buffer_size, 640 * 480 * 3)


class TestVideoFrameBuffers(TestCase):

    def test_buffer(self):
        try:
            buffer
        except NameError:
            raise SkipTest()
        frame = VideoFrame(640, 480, 'rgb24')
        frame.planes[0].update(b'01234' + (b'x' * (640 * 480 * 3 - 5)))
        buf = buffer(frame.planes[0])
        self.assertEqual(buf[1], b'1')
        self.assertEqual(buf[:7], b'01234xx')

    def test_memoryview_read(self):
        try:
            memoryview
        except NameError:
            raise SkipTest()
        frame = VideoFrame(640, 480, 'rgb24')
        frame.planes[0].update(b'01234' + (b'x' * (640 * 480 * 3 - 5)))
        mem = memoryview(frame.planes[0])
        self.assertEqual(mem.ndim, 1)
        self.assertEqual(mem.shape, (640 * 480 * 3, ))
        self.assertFalse(mem.readonly)
        self.assertEqual(mem[1], 49 if is_py3 else b'1')
        self.assertEqual(mem[:7], b'01234xx')
        mem[1] = 46 if is_py3 else b'.'
        self.assertEqual(mem[:7], b'0.234xx')


class TestVideoFrameTransforms(TestCase):

    def setUp(self):
        if not Image:
            raise SkipTest()
        self.image = Image.open(fate_png())
        self.width, self.height = self.image.size

    def test_roundtrip_low_api(self):
        if not Image:
            raise SkipTest()
        frame = VideoFrame(self.width, self.height, 'rgb24')
        frame.planes[0].update(self.image.tobytes())
        img = frame.to_image()
        img.save(self.sandboxed('roundtrip-low.jpg'))
        self.assertImagesAlmostEqual(self.image, img)

    def test_roundtrip_high_api(self):
        if not Image:
            raise SkipTest()
        frame = VideoFrame.from_image(self.image)
        img = frame.to_image()
        img.save(self.sandboxed('roundtrip-high.jpg'))
        self.assertImagesAlmostEqual(self.image, img)


class TestVideoFrameConveniences(TestCase):

    def test_basic_to_ndarray(self):
        frame = VideoFrame(640, 480, 'rgb24')
        array = frame.to_ndarray()
        self.assertEqual(array.shape, (480, 640, 3))

    def test_basic_to_nd_array(self):
        frame = VideoFrame(640, 480, 'rgb24')
        with warnings.catch_warnings(record=True) as recorded:
            array = frame.to_nd_array()
        self.assertEqual(array.shape, (480, 640, 3))

        # check deprecation warning
        self.assertEqual(len(recorded), 1)
        self.assertEqual(recorded[0].category, AttributeRenamedWarning)
        self.assertEqual(
            str(recorded[0].message),
            'VideoFrame.to_nd_array is deprecated; please use VideoFrame.to_ndarray.')


class TestVideoFrameTiming(TestCase):

    def test_reformat_pts(self):
        frame = VideoFrame(640, 480, 'rgb24')
        frame.pts = 123
        frame.time_base = '456/1' # Just to be different.
        frame = frame.reformat(320, 240)
        self.assertEqual(frame.pts, 123)
        self.assertEqual(frame.time_base, 456)


class TestVideoFrameReformat(TestCase):

    def test_reformat_identity(self):
        frame1 = VideoFrame(640, 480, 'rgb24')
        frame2 = frame1.reformat(640, 480, 'rgb24')
        self.assertIs(frame1, frame2)

    def test_reformat_colourspace(self):

        # This is allowed.
        frame = VideoFrame(640, 480, 'rgb24')
        frame2 = frame.reformat(src_colorspace=None, dst_colorspace='smpte240')

        # I thought this was not allowed, but it seems to be.
        frame = VideoFrame(640, 480, 'yuv420p')
        frame2 = frame.reformat(src_colorspace=None, dst_colorspace='smpte240')
