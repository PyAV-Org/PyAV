import warnings
from unittest import SkipTest

import numpy

from av import VideoFrame
from av.deprecation import AttributeRenamedWarning

from .common import Image, TestCase, fate_png, is_py3


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
        frame = VideoFrame()  # yuv420p
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

    def test_yuv420p_planes_align(self):
        # If we request 8-byte alignment for a width which is not a multiple of 8,
        # the line sizes are larger than the plane width.
        frame = VideoFrame(318, 238, 'yuv420p')
        self.assertEqual(len(frame.planes), 3)
        self.assertEqual(frame.planes[0].width, 318)
        self.assertEqual(frame.planes[0].height, 238)
        self.assertEqual(frame.planes[0].line_size, 320)
        self.assertEqual(frame.planes[0].buffer_size, 320 * 238)
        for i in range(1, 3):
            self.assertEqual(frame.planes[i].width, 159)
            self.assertEqual(frame.planes[i].height, 119)
            self.assertEqual(frame.planes[i].line_size, 160)
            self.assertEqual(frame.planes[i].buffer_size, 160 * 119)

    def test_rgb24_planes(self):
        frame = VideoFrame(640, 480, 'rgb24')
        self.assertEqual(len(frame.planes), 1)
        self.assertEqual(frame.planes[0].width, 640)
        self.assertEqual(frame.planes[0].height, 480)
        self.assertEqual(frame.planes[0].line_size, 640 * 3)
        self.assertEqual(frame.planes[0].buffer_size, 640 * 480 * 3)


class TestVideoFrameBuffers(TestCase):

    def test_buffer(self):
        if not hasattr(__builtins__, 'buffer'):
            raise SkipTest()

        frame = VideoFrame(640, 480, 'rgb24')
        frame.planes[0].update(b'01234' + (b'x' * (640 * 480 * 3 - 5)))
        buf = buffer(frame.planes[0])  # noqa
        self.assertEqual(buf[1], b'1')
        self.assertEqual(buf[:7], b'01234xx')

    def test_memoryview_read(self):
        if not hasattr(__builtins__, 'memoryview'):
            raise SkipTest()

        frame = VideoFrame(640, 480, 'rgb24')
        frame.planes[0].update(b'01234' + (b'x' * (640 * 480 * 3 - 5)))
        mem = memoryview(frame.planes[0])  # noqa
        self.assertEqual(mem.ndim, 1)
        self.assertEqual(mem.shape, (640 * 480 * 3, ))
        self.assertFalse(mem.readonly)
        self.assertEqual(mem[1], 49 if is_py3 else b'1')
        self.assertEqual(mem[:7], b'01234xx')
        mem[1] = 46 if is_py3 else b'.'
        self.assertEqual(mem[:7], b'0.234xx')


class TestVideoFrameImage(TestCase):

    def setUp(self):
        if not Image:
            raise SkipTest()

    def test_roundtrip(self):
        image = Image.open(fate_png())
        frame = VideoFrame.from_image(image)
        img = frame.to_image()
        img.save(self.sandboxed('roundtrip-high.jpg'))
        self.assertImagesAlmostEqual(image, img)

    def test_to_image_rgb24(self):
        sizes = [
            (318, 238),
            (320, 240),
            (500, 500),
        ]
        for width, height in sizes:
            frame = VideoFrame(width, height, format='rgb24')

            # fill video frame data
            for plane in frame.planes:
                ba = bytearray(plane.buffer_size)
                pos = 0
                for row in range(height):
                    for i in range(plane.line_size):
                        ba[pos] = i % 256
                        pos += 1
                plane.update(ba)

            # construct expected image data
            expected = bytearray(height * width * 3)
            pos = 0
            for row in range(height):
                for i in range(width * 3):
                    expected[pos] = i % 256
                    pos += 1

            img = frame.to_image()
            self.assertEqual(img.size, (width, height))
            self.assertEqual(img.tobytes(), expected)


class TestVideoFrameNdarray(TestCase):

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

    def test_ndarray_gray(self):
        array = numpy.random.randint(0, 256, size=(480, 640), dtype=numpy.uint8)
        for format in ['gray', 'gray8']:
            frame = VideoFrame.from_ndarray(array, format=format)
            self.assertEqual(frame.width, 640)
            self.assertEqual(frame.height, 480)
            self.assertEqual(frame.format.name, 'gray')
            self.assertTrue((frame.to_ndarray() == array).all())

    def test_ndarray_gray_align(self):
        array = numpy.random.randint(0, 256, size=(238, 318), dtype=numpy.uint8)
        for format in ['gray', 'gray8']:
            frame = VideoFrame.from_ndarray(array, format=format)
            self.assertEqual(frame.width, 318)
            self.assertEqual(frame.height, 238)
            self.assertEqual(frame.format.name, 'gray')
            self.assertTrue((frame.to_ndarray() == array).all())

    def test_ndarray_rgb(self):
        array = numpy.random.randint(0, 256, size=(480, 640, 3), dtype=numpy.uint8)
        for format in ['rgb24', 'bgr24']:
            frame = VideoFrame.from_ndarray(array, format=format)
            self.assertEqual(frame.width, 640)
            self.assertEqual(frame.height, 480)
            self.assertEqual(frame.format.name, format)
            self.assertTrue((frame.to_ndarray() == array).all())

    def test_ndarray_rgb_align(self):
        array = numpy.random.randint(0, 256, size=(238, 318, 3), dtype=numpy.uint8)
        for format in ['rgb24', 'bgr24']:
            frame = VideoFrame.from_ndarray(array, format=format)
            self.assertEqual(frame.width, 318)
            self.assertEqual(frame.height, 238)
            self.assertEqual(frame.format.name, format)
            self.assertTrue((frame.to_ndarray() == array).all())

    def test_ndarray_rgba(self):
        array = numpy.random.randint(0, 256, size=(480, 640, 4), dtype=numpy.uint8)
        for format in ['argb', 'rgba', 'abgr', 'bgra']:
            frame = VideoFrame.from_ndarray(array, format=format)
            self.assertEqual(frame.width, 640)
            self.assertEqual(frame.height, 480)
            self.assertEqual(frame.format.name, format)
            self.assertTrue((frame.to_ndarray() == array).all())

    def test_ndarray_rgba_align(self):
        array = numpy.random.randint(0, 256, size=(238, 318, 4), dtype=numpy.uint8)
        for format in ['argb', 'rgba', 'abgr', 'bgra']:
            frame = VideoFrame.from_ndarray(array, format=format)
            self.assertEqual(frame.width, 318)
            self.assertEqual(frame.height, 238)
            self.assertEqual(frame.format.name, format)
            self.assertTrue((frame.to_ndarray() == array).all())

    def test_ndarray_yuv420p(self):
        array = numpy.random.randint(0, 256, size=(720, 640), dtype=numpy.uint8)
        frame = VideoFrame.from_ndarray(array, format='yuv420p')
        self.assertEqual(frame.width, 640)
        self.assertEqual(frame.height, 480)
        self.assertEqual(frame.format.name, 'yuv420p')
        self.assertTrue((frame.to_ndarray() == array).all())

    def test_ndarray_yuv420p_align(self):
        array = numpy.random.randint(0, 256, size=(357, 318), dtype=numpy.uint8)
        frame = VideoFrame.from_ndarray(array, format='yuv420p')
        self.assertEqual(frame.width, 318)
        self.assertEqual(frame.height, 238)
        self.assertEqual(frame.format.name, 'yuv420p')
        self.assertTrue((frame.to_ndarray() == array).all())

    def test_ndarray_yuyv422(self):
        array = numpy.random.randint(0, 256, size=(480, 640, 2), dtype=numpy.uint8)
        frame = VideoFrame.from_ndarray(array, format='yuyv422')
        self.assertEqual(frame.width, 640)
        self.assertEqual(frame.height, 480)
        self.assertEqual(frame.format.name, 'yuyv422')
        self.assertTrue((frame.to_ndarray() == array).all())

    def test_ndarray_yuyv422_align(self):
        array = numpy.random.randint(0, 256, size=(238, 318, 2), dtype=numpy.uint8)
        frame = VideoFrame.from_ndarray(array, format='yuyv422')
        self.assertEqual(frame.width, 318)
        self.assertEqual(frame.height, 238)
        self.assertEqual(frame.format.name, 'yuyv422')
        self.assertTrue((frame.to_ndarray() == array).all())


class TestVideoFrameTiming(TestCase):

    def test_reformat_pts(self):
        frame = VideoFrame(640, 480, 'rgb24')
        frame.pts = 123
        frame.time_base = '456/1'  # Just to be different.
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
        frame.reformat(src_colorspace=None, dst_colorspace='smpte240')

        # I thought this was not allowed, but it seems to be.
        frame = VideoFrame(640, 480, 'yuv420p')
        frame.reformat(src_colorspace=None, dst_colorspace='smpte240')

    def test_reformat_pixel_format_align(self):
        height = 480
        for width in range(2, 258, 2):
            frame_yuv = VideoFrame(width, height, 'yuv420p')
            for plane in frame_yuv.planes:
                plane.update(b'\xff' * plane.buffer_size)

            expected_rgb = numpy.zeros(shape=(height, width, 3), dtype=numpy.uint8)
            expected_rgb[:, :, 0] = 255
            expected_rgb[:, :, 1] = 124
            expected_rgb[:, :, 2] = 255

            frame_rgb = frame_yuv.reformat(format='rgb24')
            array_rgb = frame_rgb.to_ndarray()
            self.assertEqual(array_rgb.shape, (height, width, 3))
            self.assertTrue((array_rgb == expected_rgb).all())
