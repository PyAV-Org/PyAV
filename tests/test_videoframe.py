import time
from fractions import Fraction
from unittest import SkipTest

import numpy

import av
from av import VideoFrame

from .common import TestCase, fate_png, fate_suite, has_pillow


class TestOpaque:
    def test_opaque(self) -> None:
        with av.open(fate_suite("h264/interlaced_crop.mp4")) as container:
            video_stream = container.streams.video[0]
            video_stream.codec_context.copy_opaque = True
            for packet_idx, packet in enumerate(container.demux()):
                packet.opaque = (time.time(), packet_idx)
                for frame in packet.decode():
                    assert isinstance(frame, av.frame.Frame)

                    if frame.opaque is None:
                        continue

                    assert type(frame.opaque) is tuple and len(frame.opaque) == 2


class TestVideoFrameConstructors(TestCase):
    def test_invalid_pixel_format(self):
        with self.assertRaises(ValueError) as cm:
            VideoFrame(640, 480, "__unknown_pix_fmt")
        assert str(cm.exception) == "not a pixel format: '__unknown_pix_fmt'"

    def test_null_constructor(self) -> None:
        frame = VideoFrame()
        assert frame.width == 0
        assert frame.height == 0
        assert frame.format.name == "yuv420p"

    def test_manual_yuv_constructor(self) -> None:
        frame = VideoFrame(640, 480, "yuv420p")
        assert frame.width == 640
        assert frame.height == 480
        assert frame.format.name == "yuv420p"

    def test_manual_rgb_constructor(self) -> None:
        frame = VideoFrame(640, 480, "rgb24")
        assert frame.width == 640
        assert frame.height == 480
        assert frame.format.name == "rgb24"


class TestVideoFramePlanes:
    def test_null_planes(self) -> None:
        frame = VideoFrame()  # yuv420p
        assert len(frame.planes) == 0

    def test_yuv420p_planes(self) -> None:
        frame = VideoFrame(640, 480, "yuv420p")
        assert len(frame.planes) == 3
        assert frame.planes[0].width == 640
        assert frame.planes[0].height == 480
        assert frame.planes[0].line_size == 640
        assert frame.planes[0].buffer_size == 640 * 480
        for i in range(1, 3):
            assert frame.planes[i].width == 320
            assert frame.planes[i].height == 240
            assert frame.planes[i].line_size == 320
            assert frame.planes[i].buffer_size == 320 * 240

    def test_yuv420p_planes_align(self):
        # If we request 8-byte alignment for a width which is not a multiple of 8,
        # the line sizes are larger than the plane width.
        frame = VideoFrame(318, 238, "yuv420p")
        assert len(frame.planes) == 3
        assert frame.planes[0].width == 318
        assert frame.planes[0].height == 238
        assert frame.planes[0].line_size == 320
        assert frame.planes[0].buffer_size == 320 * 238
        for i in range(1, 3):
            assert frame.planes[i].width == 159
            assert frame.planes[i].height == 119
            assert frame.planes[i].line_size == 160
            assert frame.planes[i].buffer_size == 160 * 119

    def test_rgb24_planes(self):
        frame = VideoFrame(640, 480, "rgb24")
        assert len(frame.planes) == 1
        assert frame.planes[0].width == 640
        assert frame.planes[0].height == 480
        assert frame.planes[0].line_size == 640 * 3
        assert frame.planes[0].buffer_size == 640 * 480 * 3


class TestVideoFrameBuffers(TestCase):
    def test_memoryview_read(self):
        frame = VideoFrame(640, 480, "rgb24")
        frame.planes[0].update(b"01234" + (b"x" * (640 * 480 * 3 - 5)))
        mem = memoryview(frame.planes[0])
        assert mem.ndim == 1
        assert mem.shape == (640 * 480 * 3,)
        self.assertFalse(mem.readonly)
        assert mem[1] == 49
        assert mem[:7] == b"01234xx"
        mem[1] = 46
        assert mem[:7] == b"0.234xx"


class TestVideoFrameImage(TestCase):
    def setUp(self):
        if not has_pillow:
            raise SkipTest()

    def test_roundtrip(self):
        import PIL.Image as Image

        image = Image.open(fate_png())
        frame = VideoFrame.from_image(image)
        img = frame.to_image()
        img.save(self.sandboxed("roundtrip-high.jpg"))
        self.assertImagesAlmostEqual(image, img)

    def test_to_image_rgb24(self):
        sizes = [
            (318, 238),
            (320, 240),
            (500, 500),
        ]
        for width, height in sizes:
            frame = VideoFrame(width, height, format="rgb24")

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
            assert img.size == (width, height)
            assert img.tobytes() == expected

    def test_to_image_with_dimensions(self):
        frame = VideoFrame(640, 480, format="rgb24")

        img = frame.to_image(width=320, height=240)
        assert img.size == (320, 240)


class TestVideoFrameNdarray(TestCase):
    def assertPixelValue16(self, plane, expected, byteorder: str):
        view = memoryview(plane)
        if byteorder == "big":
            assert view[0] == (expected >> 8 & 0xFF)
            assert view[1] == expected & 0xFF
        else:
            assert view[0] == expected & 0xFF
            assert view[1] == (expected >> 8 & 0xFF)

    def test_basic_to_ndarray(self):
        frame = VideoFrame(640, 480, "rgb24")
        array = frame.to_ndarray()
        assert array.shape == (480, 640, 3)

    def test_ndarray_gray(self):
        array = numpy.random.randint(0, 256, size=(480, 640), dtype=numpy.uint8)
        for format in ["gray", "gray8"]:
            frame = VideoFrame.from_ndarray(array, format=format)
            assert frame.width == 640
            assert frame.height == 480
            assert frame.format.name == "gray"
            self.assertNdarraysEqual(frame.to_ndarray(), array)

    def test_ndarray_gray_align(self):
        array = numpy.random.randint(0, 256, size=(238, 318), dtype=numpy.uint8)
        for format in ["gray", "gray8"]:
            frame = VideoFrame.from_ndarray(array, format=format)
            assert frame.width == 318
            assert frame.height == 238
            assert frame.format.name == "gray"
            self.assertNdarraysEqual(frame.to_ndarray(), array)

    def test_ndarray_rgb(self):
        array = numpy.random.randint(0, 256, size=(480, 640, 3), dtype=numpy.uint8)
        for format in ["rgb24", "bgr24"]:
            frame = VideoFrame.from_ndarray(array, format=format)
            assert frame.width == 640
            assert frame.height == 480
            assert frame.format.name == format
            self.assertNdarraysEqual(frame.to_ndarray(), array)

    def test_ndarray_rgb_align(self):
        array = numpy.random.randint(0, 256, size=(238, 318, 3), dtype=numpy.uint8)
        for format in ["rgb24", "bgr24"]:
            frame = VideoFrame.from_ndarray(array, format=format)
            assert frame.width == 318
            assert frame.height == 238
            assert frame.format.name == format
            self.assertNdarraysEqual(frame.to_ndarray(), array)

    def test_ndarray_rgba(self):
        array = numpy.random.randint(0, 256, size=(480, 640, 4), dtype=numpy.uint8)
        for format in ["argb", "rgba", "abgr", "bgra"]:
            frame = VideoFrame.from_ndarray(array, format=format)
            assert frame.width == 640
            assert frame.height == 480
            assert frame.format.name == format
            self.assertNdarraysEqual(frame.to_ndarray(), array)

    def test_ndarray_rgba_align(self):
        array = numpy.random.randint(0, 256, size=(238, 318, 4), dtype=numpy.uint8)
        for format in ["argb", "rgba", "abgr", "bgra"]:
            frame = VideoFrame.from_ndarray(array, format=format)
            assert frame.width == 318
            assert frame.height == 238
            assert frame.format.name == format
            self.assertNdarraysEqual(frame.to_ndarray(), array)

    def test_ndarray_gbrp(self):
        array = numpy.random.randint(0, 256, size=(480, 640, 3), dtype=numpy.uint8)
        frame = VideoFrame.from_ndarray(array, format="gbrp")
        assert frame.width == 640
        assert frame.height == 480
        assert frame.format.name == "gbrp"
        self.assertNdarraysEqual(frame.to_ndarray(), array)

    def test_ndarray_gbrp_align(self):
        array = numpy.random.randint(0, 256, size=(238, 318, 3), dtype=numpy.uint8)
        frame = VideoFrame.from_ndarray(array, format="gbrp")
        assert frame.width == 318
        assert frame.height == 238
        assert frame.format.name == "gbrp"
        self.assertNdarraysEqual(frame.to_ndarray(), array)

    def test_ndarray_gbrp10(self):
        array = numpy.random.randint(0, 1024, size=(480, 640, 3), dtype=numpy.uint16)
        for format in ["gbrp10be", "gbrp10le"]:
            frame = VideoFrame.from_ndarray(array, format=format)
            assert frame.width == 640
            assert frame.height == 480
            assert frame.format.name == format
            self.assertNdarraysEqual(frame.to_ndarray(), array)

    def test_ndarray_gbrp10_align(self):
        array = numpy.random.randint(0, 1024, size=(238, 318, 3), dtype=numpy.uint16)
        for format in ["gbrp10be", "gbrp10le"]:
            frame = VideoFrame.from_ndarray(array, format=format)
            assert frame.width == 318
            assert frame.height == 238
            assert frame.format.name == format
            self.assertNdarraysEqual(frame.to_ndarray(), array)

    def test_ndarray_gbrp12(self):
        array = numpy.random.randint(0, 4096, size=(480, 640, 3), dtype=numpy.uint16)
        for format in ["gbrp12be", "gbrp12le"]:
            frame = VideoFrame.from_ndarray(array, format=format)
            assert frame.width == 640
            assert frame.height == 480
            assert frame.format.name == format
            self.assertNdarraysEqual(frame.to_ndarray(), array)

    def test_ndarray_gbrp12_align(self):
        array = numpy.random.randint(0, 4096, size=(238, 318, 3), dtype=numpy.uint16)
        for format in ["gbrp12be", "gbrp12le"]:
            frame = VideoFrame.from_ndarray(array, format=format)
            assert frame.width == 318
            assert frame.height == 238
            assert frame.format.name == format
            self.assertNdarraysEqual(frame.to_ndarray(), array)

    def test_ndarray_gbrp14(self):
        array = numpy.random.randint(0, 16384, size=(480, 640, 3), dtype=numpy.uint16)
        for format in ["gbrp14be", "gbrp14le"]:
            frame = VideoFrame.from_ndarray(array, format=format)
            assert frame.width == 640
            assert frame.height == 480
            assert frame.format.name == format
            self.assertNdarraysEqual(frame.to_ndarray(), array)

    def test_ndarray_gbrp14_align(self):
        array = numpy.random.randint(0, 16384, size=(238, 318, 3), dtype=numpy.uint16)
        for format in ["gbrp14be", "gbrp14le"]:
            frame = VideoFrame.from_ndarray(array, format=format)
            assert frame.width == 318
            assert frame.height == 238
            assert frame.format.name == format
            self.assertNdarraysEqual(frame.to_ndarray(), array)

    def test_ndarray_gbrp16(self):
        array = numpy.random.randint(0, 65536, size=(480, 640, 3), dtype=numpy.uint16)
        for format in ["gbrp16be", "gbrp16le"]:
            frame = VideoFrame.from_ndarray(array, format=format)
            assert frame.width == 640
            assert frame.height == 480
            assert frame.format.name == format
            self.assertNdarraysEqual(frame.to_ndarray(), array)

    def test_ndarray_gbrp16_align(self):
        array = numpy.random.randint(0, 65536, size=(238, 318, 3), dtype=numpy.uint16)
        for format in ["gbrp16be", "gbrp16le"]:
            frame = VideoFrame.from_ndarray(array, format=format)
            assert frame.width == 318
            assert frame.height == 238
            assert frame.format.name == format
            self.assertNdarraysEqual(frame.to_ndarray(), array)

    def test_ndarray_gbrpf32(self):
        array = numpy.random.random_sample(size=(480, 640, 3)).astype(numpy.float32)
        for format in ["gbrpf32be", "gbrpf32le"]:
            frame = VideoFrame.from_ndarray(array, format=format)
            assert frame.width == 640
            assert frame.height == 480
            assert frame.format.name == format
            self.assertNdarraysEqual(frame.to_ndarray(), array)

    def test_ndarray_gbrpf32_align(self):
        array = numpy.random.random_sample(size=(238, 318, 3)).astype(numpy.float32)
        for format in ["gbrpf32be", "gbrpf32le"]:
            frame = VideoFrame.from_ndarray(array, format=format)
            assert frame.width == 318
            assert frame.height == 238
            assert frame.format.name == format
            self.assertNdarraysEqual(frame.to_ndarray(), array)

    def test_ndarray_yuv420p(self):
        array = numpy.random.randint(0, 256, size=(720, 640), dtype=numpy.uint8)
        frame = VideoFrame.from_ndarray(array, format="yuv420p")
        assert frame.width == 640
        assert frame.height == 480
        assert frame.format.name == "yuv420p"
        self.assertNdarraysEqual(frame.to_ndarray(), array)

    def test_ndarray_yuv420p_align(self):
        array = numpy.random.randint(0, 256, size=(357, 318), dtype=numpy.uint8)
        frame = VideoFrame.from_ndarray(array, format="yuv420p")
        assert frame.width == 318
        assert frame.height == 238
        assert frame.format.name == "yuv420p"
        self.assertNdarraysEqual(frame.to_ndarray(), array)

    def test_ndarray_yuvj420p(self):
        array = numpy.random.randint(0, 256, size=(720, 640), dtype=numpy.uint8)
        frame = VideoFrame.from_ndarray(array, format="yuvj420p")
        assert frame.width == 640
        assert frame.height == 480
        assert frame.format.name == "yuvj420p"
        self.assertNdarraysEqual(frame.to_ndarray(), array)

    def test_ndarray_yuyv422(self):
        array = numpy.random.randint(0, 256, size=(480, 640, 2), dtype=numpy.uint8)
        frame = VideoFrame.from_ndarray(array, format="yuyv422")
        assert frame.width == 640
        assert frame.height == 480
        assert frame.format.name == "yuyv422"
        self.assertNdarraysEqual(frame.to_ndarray(), array)

    def test_ndarray_yuv444p(self):
        array = numpy.random.randint(0, 256, size=(3, 480, 640), dtype=numpy.uint8)
        frame = VideoFrame.from_ndarray(array, format="yuv444p")
        assert frame.width == 640
        assert frame.height == 480
        assert frame.format.name == "yuv444p"
        self.assertNdarraysEqual(frame.to_ndarray(), array)

    def test_ndarray_yuvj444p(self):
        array = numpy.random.randint(0, 256, size=(3, 480, 640), dtype=numpy.uint8)
        frame = VideoFrame.from_ndarray(array, format="yuvj444p")
        assert frame.width == 640
        assert frame.height == 480
        assert frame.format.name == "yuvj444p"
        self.assertNdarraysEqual(frame.to_ndarray(), array)

    def test_ndarray_yuyv422_align(self):
        array = numpy.random.randint(0, 256, size=(238, 318, 2), dtype=numpy.uint8)
        frame = VideoFrame.from_ndarray(array, format="yuyv422")
        assert frame.width == 318
        assert frame.height == 238
        assert frame.format.name == "yuyv422"
        self.assertNdarraysEqual(frame.to_ndarray(), array)

    def test_ndarray_gray16be(self):
        array = numpy.random.randint(0, 65536, size=(480, 640), dtype=numpy.uint16)
        frame = VideoFrame.from_ndarray(array, format="gray16be")
        assert frame.width == 640
        assert frame.height == 480
        assert frame.format.name == "gray16be"
        self.assertNdarraysEqual(frame.to_ndarray(), array)

        # check endianness by examining value of first pixel
        self.assertPixelValue16(frame.planes[0], array[0][0], "big")

    def test_ndarray_gray16le(self):
        array = numpy.random.randint(0, 65536, size=(480, 640), dtype=numpy.uint16)
        frame = VideoFrame.from_ndarray(array, format="gray16le")
        assert frame.width == 640
        assert frame.height == 480
        assert frame.format.name == "gray16le"
        self.assertNdarraysEqual(frame.to_ndarray(), array)

        # check endianness by examining value of first pixel
        self.assertPixelValue16(frame.planes[0], array[0][0], "little")

    def test_ndarray_rgb48be(self):
        array = numpy.random.randint(0, 65536, size=(480, 640, 3), dtype=numpy.uint16)
        frame = VideoFrame.from_ndarray(array, format="rgb48be")
        assert frame.width == 640
        assert frame.height == 480
        assert frame.format.name == "rgb48be"
        self.assertNdarraysEqual(frame.to_ndarray(), array)

        # check endianness by examining red value of first pixel
        self.assertPixelValue16(frame.planes[0], array[0][0][0], "big")

    def test_ndarray_rgb48le(self):
        array = numpy.random.randint(0, 65536, size=(480, 640, 3), dtype=numpy.uint16)
        frame = VideoFrame.from_ndarray(array, format="rgb48le")
        assert frame.width == 640
        assert frame.height == 480
        assert frame.format.name == "rgb48le"
        self.assertNdarraysEqual(frame.to_ndarray(), array)

        # check endianness by examining red value of first pixel
        self.assertPixelValue16(frame.planes[0], array[0][0][0], "little")

    def test_ndarray_rgb48le_align(self):
        array = numpy.random.randint(0, 65536, size=(238, 318, 3), dtype=numpy.uint16)
        frame = VideoFrame.from_ndarray(array, format="rgb48le")
        assert frame.width == 318
        assert frame.height == 238
        assert frame.format.name == "rgb48le"
        self.assertNdarraysEqual(frame.to_ndarray(), array)

        # check endianness by examining red value of first pixel
        self.assertPixelValue16(frame.planes[0], array[0][0][0], "little")

    def test_ndarray_rgba64be(self):
        array = numpy.random.randint(0, 65536, size=(480, 640, 4), dtype=numpy.uint16)
        frame = VideoFrame.from_ndarray(array, format="rgba64be")
        assert frame.width == 640
        assert frame.height == 480
        assert frame.format.name == "rgba64be"
        self.assertNdarraysEqual(frame.to_ndarray(), array)

        # check endianness by examining red value of first pixel
        self.assertPixelValue16(frame.planes[0], array[0][0][0], "big")

    def test_ndarray_rgba64le(self):
        array = numpy.random.randint(0, 65536, size=(480, 640, 4), dtype=numpy.uint16)
        frame = VideoFrame.from_ndarray(array, format="rgba64le")
        assert frame.width == 640
        assert frame.height == 480
        assert frame.format.name == "rgba64le"
        self.assertNdarraysEqual(frame.to_ndarray(), array)

        # check endianness by examining red value of first pixel
        self.assertPixelValue16(frame.planes[0], array[0][0][0], "little")

    def test_ndarray_rgb8(self):
        array = numpy.random.randint(0, 256, size=(480, 640), dtype=numpy.uint8)
        frame = VideoFrame.from_ndarray(array, format="rgb8")
        assert frame.width == 640
        assert frame.height == 480
        assert frame.format.name == "rgb8"
        self.assertNdarraysEqual(frame.to_ndarray(), array)

    def test_ndarray_bgr8(self):
        array = numpy.random.randint(0, 256, size=(480, 640), dtype=numpy.uint8)
        frame = VideoFrame.from_ndarray(array, format="bgr8")
        assert frame.width == 640
        assert frame.height == 480
        assert frame.format.name == "bgr8"
        self.assertNdarraysEqual(frame.to_ndarray(), array)

    def test_ndarray_pal8(self):
        array = numpy.random.randint(0, 256, size=(480, 640), dtype=numpy.uint8)
        palette = numpy.random.randint(0, 256, size=(256, 4), dtype=numpy.uint8)
        frame = VideoFrame.from_ndarray((array, palette), format="pal8")
        assert frame.width == 640
        assert frame.height == 480
        assert frame.format.name == "pal8"
        returned = frame.to_ndarray()
        self.assertTrue((type(returned) is tuple) and len(returned) == 2)
        self.assertNdarraysEqual(returned[0], array)
        self.assertNdarraysEqual(returned[1], palette)

    def test_ndarray_nv12(self):
        array = numpy.random.randint(0, 256, size=(720, 640), dtype=numpy.uint8)
        frame = VideoFrame.from_ndarray(array, format="nv12")
        assert frame.width == 640
        assert frame.height == 480
        assert frame.format.name == "nv12"
        self.assertNdarraysEqual(frame.to_ndarray(), array)

    def test_ndarray_nv12_align(self):
        array = numpy.random.randint(0, 256, size=(357, 318), dtype=numpy.uint8)
        frame = VideoFrame.from_ndarray(array, format="nv12")
        assert frame.width == 318
        assert frame.height == 238
        assert frame.format.name == "nv12"
        self.assertNdarraysEqual(frame.to_ndarray(), array)


class TestVideoFrameNumpyBuffer(TestCase):
    def test_shares_memory_gray(self):
        array = numpy.random.randint(0, 256, size=(357, 318), dtype=numpy.uint8)
        frame = VideoFrame.from_numpy_buffer(array, "gray")
        self.assertNdarraysEqual(frame.to_ndarray(), array)

        # overwrite the array, the contents thereof
        array[...] = numpy.random.randint(0, 256, size=(357, 318), dtype=numpy.uint8)
        # Make sure the frame reflects that
        self.assertNdarraysEqual(frame.to_ndarray(), array)

    def test_shares_memory_gray8(self):
        array = numpy.random.randint(0, 256, size=(357, 318), dtype=numpy.uint8)
        frame = VideoFrame.from_numpy_buffer(array, "gray8")
        self.assertNdarraysEqual(frame.to_ndarray(), array)

        # overwrite the array, the contents thereof
        array[...] = numpy.random.randint(0, 256, size=(357, 318), dtype=numpy.uint8)
        # Make sure the frame reflects that
        self.assertNdarraysEqual(frame.to_ndarray(), array)

    def test_shares_memory_rgb8(self):
        array = numpy.random.randint(0, 256, size=(357, 318), dtype=numpy.uint8)
        frame = VideoFrame.from_numpy_buffer(array, "rgb8")
        self.assertNdarraysEqual(frame.to_ndarray(), array)

        # overwrite the array, the contents thereof
        array[...] = numpy.random.randint(0, 256, size=(357, 318), dtype=numpy.uint8)
        # Make sure the frame reflects that
        self.assertNdarraysEqual(frame.to_ndarray(), array)

    def test_shares_memory_bgr8(self):
        array = numpy.random.randint(0, 256, size=(357, 318), dtype=numpy.uint8)
        frame = VideoFrame.from_numpy_buffer(array, "bgr8")
        self.assertNdarraysEqual(frame.to_ndarray(), array)

        # overwrite the array, the contents thereof
        array[...] = numpy.random.randint(0, 256, size=(357, 318), dtype=numpy.uint8)
        # Make sure the frame reflects that
        self.assertNdarraysEqual(frame.to_ndarray(), array)

    def test_shares_memory_rgb24(self):
        array = numpy.random.randint(0, 256, size=(357, 318, 3), dtype=numpy.uint8)
        frame = VideoFrame.from_numpy_buffer(array, "rgb24")
        self.assertNdarraysEqual(frame.to_ndarray(), array)

        # overwrite the array, the contents thereof
        array[...] = numpy.random.randint(0, 256, size=(357, 318, 3), dtype=numpy.uint8)
        # Make sure the frame reflects that
        self.assertNdarraysEqual(frame.to_ndarray(), array)

    def test_shares_memory_yuv420p(self):
        array = numpy.random.randint(
            0, 256, size=(512 * 6 // 4, 256), dtype=numpy.uint8
        )
        frame = VideoFrame.from_numpy_buffer(array, "yuv420p")
        self.assertNdarraysEqual(frame.to_ndarray(), array)

        # overwrite the array, the contents thereof
        array[...] = numpy.random.randint(0, 256, size=array.shape, dtype=numpy.uint8)
        # Make sure the frame reflects that
        self.assertNdarraysEqual(frame.to_ndarray(), array)

    def test_shares_memory_yuvj420p(self):
        array = numpy.random.randint(
            0, 256, size=(512 * 6 // 4, 256), dtype=numpy.uint8
        )
        frame = VideoFrame.from_numpy_buffer(array, "yuvj420p")
        self.assertNdarraysEqual(frame.to_ndarray(), array)

        # overwrite the array, the contents thereof
        array[...] = numpy.random.randint(0, 256, size=array.shape, dtype=numpy.uint8)
        # Make sure the frame reflects that
        self.assertNdarraysEqual(frame.to_ndarray(), array)

    def test_shares_memory_nv12(self):
        array = numpy.random.randint(
            0, 256, size=(512 * 6 // 4, 256), dtype=numpy.uint8
        )
        frame = VideoFrame.from_numpy_buffer(array, "nv12")
        self.assertNdarraysEqual(frame.to_ndarray(), array)

        # overwrite the array, the contents thereof
        array[...] = numpy.random.randint(0, 256, size=array.shape, dtype=numpy.uint8)
        # Make sure the frame reflects that
        self.assertNdarraysEqual(frame.to_ndarray(), array)

    def test_shares_memory_bgr24(self):
        array = numpy.random.randint(0, 256, size=(357, 318, 3), dtype=numpy.uint8)
        frame = VideoFrame.from_numpy_buffer(array, "bgr24")
        self.assertNdarraysEqual(frame.to_ndarray(), array)

        # overwrite the array, the contents thereof
        array[...] = numpy.random.randint(0, 256, size=(357, 318, 3), dtype=numpy.uint8)
        # Make sure the frame reflects that
        self.assertNdarraysEqual(frame.to_ndarray(), array)


class TestVideoFrameTiming(TestCase):
    def test_reformat_pts(self) -> None:
        frame = VideoFrame(640, 480, "rgb24")
        frame.pts = 123
        frame.time_base = Fraction("456/1")
        frame = frame.reformat(320, 240)
        assert frame.pts == 123
        assert frame.time_base == 456


class TestVideoFrameReformat(TestCase):
    def test_reformat_identity(self):
        frame1 = VideoFrame(640, 480, "rgb24")
        frame2 = frame1.reformat(640, 480, "rgb24")
        assert frame1 is frame2

    def test_reformat_colourspace(self):
        # This is allowed.
        frame = VideoFrame(640, 480, "rgb24")
        frame.reformat(src_colorspace=None, dst_colorspace="smpte240")

        # I thought this was not allowed, but it seems to be.
        frame = VideoFrame(640, 480, "yuv420p")
        frame.reformat(src_colorspace=None, dst_colorspace="smpte240")

    def test_reformat_pixel_format_align(self):
        height = 480
        for width in range(2, 258, 2):
            frame_yuv = VideoFrame(width, height, "yuv420p")
            for plane in frame_yuv.planes:
                plane.update(b"\xff" * plane.buffer_size)

            expected_rgb = numpy.zeros(shape=(height, width, 3), dtype=numpy.uint8)
            expected_rgb[:, :, 0] = 255
            expected_rgb[:, :, 1] = 124
            expected_rgb[:, :, 2] = 255

            frame_rgb = frame_yuv.reformat(format="rgb24")
            self.assertNdarraysEqual(frame_rgb.to_ndarray(), expected_rgb)
