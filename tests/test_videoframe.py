import time
from fractions import Fraction
from unittest import SkipTest

import numpy
import pytest

import av
from av import VideoFrame
from av.frame import Frame
from av.video.frame import supported_np_pix_fmts
from av.video.reformatter import ColorRange, Colorspace, Interpolation

from .common import TestCase, assertNdarraysEqual, fate_png, fate_suite


def assertPixelValue16(plane, expected, byteorder: str) -> None:
    view = memoryview(plane)
    if byteorder == "big":
        assert view[0] == (expected >> 8 & 0xFF)
        assert view[1] == expected & 0xFF
    else:
        assert view[0] == expected & 0xFF
        assert view[1] == (expected >> 8 & 0xFF)


def test_frame_duration_matches_packet() -> None:
    with av.open(fate_suite("h264/interlaced_crop.mp4")) as container:
        packet_durations = [
            (p.pts, p.duration) for p in container.demux() if p.pts is not None
        ]
        packet_durations.sort(key=lambda x: x[0])

    with av.open(fate_suite("h264/interlaced_crop.mp4")) as container:
        frame_durations = [(f.pts, f.duration) for f in container.decode(video=0)]
        frame_durations.sort(key=lambda x: x[0])

    assert len(packet_durations) == len(frame_durations)
    assert all(pd[1] == fd[1] for pd, fd in zip(packet_durations, frame_durations))


def test_invalid_pixel_format() -> None:
    with pytest.raises(ValueError, match="not a pixel format: '__unknown_pix_fmt'"):
        VideoFrame(640, 480, "__unknown_pix_fmt")


def test_null_constructor() -> None:
    frame = VideoFrame()
    assert frame.width == 0
    assert frame.height == 0
    assert frame.format.name == "yuv420p"


def test_manual_yuv_constructor() -> None:
    frame = VideoFrame(640, 480, "yuv420p")
    assert frame.width == 640
    assert frame.height == 480
    assert frame.format.name == "yuv420p"


def test_manual_rgb_constructor() -> None:
    frame = VideoFrame(640, 480, "rgb24")
    assert frame.width == 640
    assert frame.height == 480
    assert frame.format.name == "rgb24"


def test_null_planes() -> None:
    frame = VideoFrame()  # yuv420p
    assert len(frame.planes) == 0


def test_yuv420p_planes() -> None:
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


def test_yuv420p_planes_align() -> None:
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


def test_rgb24_planes() -> None:
    frame = VideoFrame(640, 480, "rgb24")
    assert len(frame.planes) == 1
    assert frame.planes[0].width == 640
    assert frame.planes[0].height == 480
    assert frame.planes[0].line_size == 640 * 3
    assert frame.planes[0].buffer_size == 640 * 480 * 3


def test_memoryview_read() -> None:
    frame = VideoFrame(640, 480, "rgb24")
    frame.planes[0].update(b"01234" + (b"x" * (640 * 480 * 3 - 5)))
    mem = memoryview(frame.planes[0])
    assert mem.ndim == 1
    assert mem.shape == (640 * 480 * 3,)
    assert not mem.readonly
    assert mem[1] == 49
    assert mem[:7] == b"01234xx"
    mem[1] = 46
    assert mem[:7] == b"0.234xx"


def test_interpolation() -> None:
    container = av.open(fate_png())
    for _ in container.decode(video=0):
        frame = _
        break

    assert frame.width == 330 and frame.height == 330

    img = frame.reformat(width=200, height=100, interpolation=Interpolation.BICUBIC)
    assert img.width == 200 and img.height == 100

    img = frame.reformat(width=200, height=100, interpolation="BICUBIC")
    assert img.width == 200 and img.height == 100

    img = frame.reformat(
        width=200, height=100, interpolation=int(Interpolation.BICUBIC)
    )
    assert img.width == 200 and img.height == 100


def test_basic_to_ndarray() -> None:
    array = VideoFrame(640, 480, "rgb24").to_ndarray()
    assert array.shape == (480, 640, 3)


def test_ndarray_gray() -> None:
    array = numpy.random.randint(0, 256, size=(480, 640), dtype=numpy.uint8)
    for format in ("gray", "gray8"):
        frame = VideoFrame.from_ndarray(array, format=format)
        assert format in supported_np_pix_fmts
        assert frame.width == 640 and frame.height == 480
        assert frame.format.name == "gray"
        assertNdarraysEqual(frame.to_ndarray(), array)


def test_ndarray_gray_align() -> None:
    array = numpy.random.randint(0, 256, size=(238, 318), dtype=numpy.uint8)
    for format in ("gray", "gray8"):
        frame = VideoFrame.from_ndarray(array, format=format)
        assert format in supported_np_pix_fmts
        assert frame.width == 318 and frame.height == 238
        assert frame.format.name == "gray"
        assertNdarraysEqual(frame.to_ndarray(), array)


def test_ndarray_gray9be() -> None:
    array = numpy.random.randint(0, 512, size=(480, 640), dtype=numpy.uint16)
    frame = VideoFrame.from_ndarray(array, format="gray9be")
    assert frame.width == 640 and frame.height == 480
    assert frame.format.name == "gray9be"
    assertNdarraysEqual(frame.to_ndarray(), array)

    # check endianness by examining value of first pixel
    assertPixelValue16(frame.planes[0], array[0][0], "big")


def test_ndarray_gray9le() -> None:
    array = numpy.random.randint(0, 512, size=(480, 640), dtype=numpy.uint16)
    frame = VideoFrame.from_ndarray(array, format="gray9le")
    assert frame.width == 640 and frame.height == 480
    assert frame.format.name == "gray9le"
    assertNdarraysEqual(frame.to_ndarray(), array)

    # check endianness by examining value of first pixel
    assertPixelValue16(frame.planes[0], array[0][0], "little")


def test_ndarray_gray10be() -> None:
    array = numpy.random.randint(0, 1024, size=(480, 640), dtype=numpy.uint16)
    frame = VideoFrame.from_ndarray(array, format="gray10be")
    assert frame.width == 640 and frame.height == 480
    assert frame.format.name == "gray10be"
    assertNdarraysEqual(frame.to_ndarray(), array)

    # check endianness by examining value of first pixel
    assertPixelValue16(frame.planes[0], array[0][0], "big")


def test_ndarray_gray10le() -> None:
    array = numpy.random.randint(0, 1024, size=(480, 640), dtype=numpy.uint16)
    frame = VideoFrame.from_ndarray(array, format="gray10le")
    assert frame.width == 640 and frame.height == 480
    assert frame.format.name == "gray10le"
    assertNdarraysEqual(frame.to_ndarray(), array)

    # check endianness by examining value of first pixel
    assertPixelValue16(frame.planes[0], array[0][0], "little")


def test_ndarray_gray12be() -> None:
    array = numpy.random.randint(0, 4096, size=(480, 640), dtype=numpy.uint16)
    frame = VideoFrame.from_ndarray(array, format="gray12be")
    assert frame.width == 640 and frame.height == 480
    assert frame.format.name == "gray12be"
    assertNdarraysEqual(frame.to_ndarray(), array)

    # check endianness by examining value of first pixel
    assertPixelValue16(frame.planes[0], array[0][0], "big")


def test_ndarray_gray12le() -> None:
    array = numpy.random.randint(0, 4096, size=(480, 640), dtype=numpy.uint16)
    frame = VideoFrame.from_ndarray(array, format="gray12le")
    assert frame.width == 640 and frame.height == 480
    assert frame.format.name == "gray12le"
    assertNdarraysEqual(frame.to_ndarray(), array)

    # check endianness by examining value of first pixel
    assertPixelValue16(frame.planes[0], array[0][0], "little")


def test_ndarray_gray14be() -> None:
    array = numpy.random.randint(0, 16384, size=(480, 640), dtype=numpy.uint16)
    frame = VideoFrame.from_ndarray(array, format="gray14be")
    assert frame.width == 640 and frame.height == 480
    assert frame.format.name == "gray14be"
    assertNdarraysEqual(frame.to_ndarray(), array)

    # check endianness by examining value of first pixel
    assertPixelValue16(frame.planes[0], array[0][0], "big")


def test_ndarray_gray14le() -> None:
    array = numpy.random.randint(0, 16384, size=(480, 640), dtype=numpy.uint16)
    frame = VideoFrame.from_ndarray(array, format="gray14le")
    assert frame.width == 640 and frame.height == 480
    assert frame.format.name == "gray14le"
    assertNdarraysEqual(frame.to_ndarray(), array)

    # check endianness by examining value of first pixel
    assertPixelValue16(frame.planes[0], array[0][0], "little")


def test_ndarray_gray16be() -> None:
    array = numpy.random.randint(0, 65536, size=(480, 640), dtype=numpy.uint16)
    frame = VideoFrame.from_ndarray(array, format="gray16be")
    assert frame.width == 640 and frame.height == 480
    assert frame.format.name == "gray16be"
    assertNdarraysEqual(frame.to_ndarray(), array)

    # check endianness by examining value of first pixel
    assertPixelValue16(frame.planes[0], array[0][0], "big")


def test_ndarray_gray16le() -> None:
    array = numpy.random.randint(0, 65536, size=(480, 640), dtype=numpy.uint16)
    frame = VideoFrame.from_ndarray(array, format="gray16le")
    assert frame.width == 640 and frame.height == 480
    assert frame.format.name == "gray16le"
    assertNdarraysEqual(frame.to_ndarray(), array)

    # check endianness by examining value of first pixel
    assertPixelValue16(frame.planes[0], array[0][0], "little")


def test_ndarray_grayf32() -> None:
    array = numpy.random.random_sample(size=(480, 640)).astype(numpy.float32)
    for format in ("grayf32be", "grayf32le"):
        frame = VideoFrame.from_ndarray(array, format=format)
        assert format in supported_np_pix_fmts
        assert frame.width == 640 and frame.height == 480
        assert frame.format.name == format
        assertNdarraysEqual(frame.to_ndarray(), array)


def test_ndarray_grayf32_align() -> None:
    array = numpy.random.random_sample(size=(238, 318)).astype(numpy.float32)
    for format in ("grayf32be", "grayf32le"):
        frame = VideoFrame.from_ndarray(array, format=format)
        assert format in supported_np_pix_fmts
        assert frame.width == 318 and frame.height == 238
        assert frame.format.name == format
        assertNdarraysEqual(frame.to_ndarray(), array)


def test_ndarray_rgb() -> None:
    array = numpy.random.randint(0, 256, size=(480, 640, 3), dtype=numpy.uint8)
    for format in ("rgb24", "bgr24"):
        frame = VideoFrame.from_ndarray(array, format=format)
        assert format in supported_np_pix_fmts
        assert frame.width == 640 and frame.height == 480
        assert frame.format.name == format
        assertNdarraysEqual(frame.to_ndarray(), array)


def test_ndarray_rgb_align() -> None:
    array = numpy.random.randint(0, 256, size=(238, 318, 3), dtype=numpy.uint8)
    for format in ("rgb24", "bgr24"):
        frame = VideoFrame.from_ndarray(array, format=format)
        assert format in supported_np_pix_fmts
        assert frame.width == 318 and frame.height == 238
        assert frame.format.name == format
        assertNdarraysEqual(frame.to_ndarray(), array)


def test_ndarray_rgbf32() -> None:
    array = numpy.random.random_sample(size=(480, 640, 3)).astype(numpy.float32)
    for format in ("rgbf32be", "rgbf32le"):
        frame = VideoFrame.from_ndarray(array, format=format)
        assert frame.width == 640 and frame.height == 480
        assert frame.format.name == format
        assertNdarraysEqual(frame.to_ndarray(), array)


def test_ndarray_rgba() -> None:
    array = numpy.random.randint(0, 256, size=(480, 640, 4), dtype=numpy.uint8)
    for format in ("argb", "rgba", "abgr", "bgra"):
        frame = VideoFrame.from_ndarray(array, format=format)
        assert format in supported_np_pix_fmts
        assert frame.width == 640 and frame.height == 480
        assert frame.format.name == format
        assertNdarraysEqual(frame.to_ndarray(), array)


def test_ndarray_rgba_align() -> None:
    array = numpy.random.randint(0, 256, size=(238, 318, 4), dtype=numpy.uint8)
    for format in ("argb", "rgba", "abgr", "bgra"):
        frame = VideoFrame.from_ndarray(array, format=format)
        assert format in supported_np_pix_fmts
        assert frame.width == 318 and frame.height == 238
        assert frame.format.name == format
        assertNdarraysEqual(frame.to_ndarray(), array)


def test_ndarray_bayer8() -> None:
    array = numpy.random.randint(0, 256, size=(480, 640), dtype=numpy.uint8)
    for format in ("bayer_bggr8", "bayer_gbrg8", "bayer_grbg8", "bayer_rggb8"):
        frame = VideoFrame.from_ndarray(array, format=format)
        assert format in supported_np_pix_fmts
        assert frame.width == 640 and frame.height == 480
        assert frame.format.name == format
        assertNdarraysEqual(frame.to_ndarray(), array)


def test_ndarray_bayer16() -> None:
    array = numpy.random.randint(0, 65536, size=(480, 640), dtype=numpy.uint16)
    for format in (
        "bayer_bggr16be",
        "bayer_bggr16le",
        "bayer_gbrg16be",
        "bayer_gbrg16le",
        "bayer_grbg16be",
        "bayer_grbg16le",
        "bayer_rggb16be",
        "bayer_rggb16le",
    ):
        frame = VideoFrame.from_ndarray(array, format=format)
        assert format in supported_np_pix_fmts
        assert frame.width == 640 and frame.height == 480
        assert frame.format.name == format
        assertNdarraysEqual(frame.to_ndarray(), array)


def test_ndarray_gbrap() -> None:
    array = numpy.random.randint(0, 256, size=(480, 640, 4), dtype=numpy.uint8)
    frame = VideoFrame.from_ndarray(array, format="gbrap")
    assert frame.width == 640 and frame.height == 480
    assert frame.format.name == "gbrap"
    assertNdarraysEqual(frame.to_ndarray(), array)


def test_ndarray_gbrap_align() -> None:
    array = numpy.random.randint(0, 256, size=(238, 318, 4), dtype=numpy.uint8)
    frame = VideoFrame.from_ndarray(array, format="gbrap")
    assert frame.width == 318 and frame.height == 238
    assert frame.format.name == "gbrap"
    assertNdarraysEqual(frame.to_ndarray(), array)


def test_ndarray_gbrap10() -> None:
    array = numpy.random.randint(0, 1024, size=(480, 640, 4), dtype=numpy.uint16)
    for format in ("gbrap10be", "gbrap10le"):
        frame = VideoFrame.from_ndarray(array, format=format)
        assert format in supported_np_pix_fmts
        assert frame.width == 640 and frame.height == 480
        assert frame.format.name == format
        assertNdarraysEqual(frame.to_ndarray(), array)


def test_ndarray_gbrap10_align() -> None:
    array = numpy.random.randint(0, 1024, size=(238, 318, 4), dtype=numpy.uint16)
    for format in ("gbrap10be", "gbrap10le"):
        frame = VideoFrame.from_ndarray(array, format=format)
        assert format in supported_np_pix_fmts
        assert frame.width == 318 and frame.height == 238
        assert frame.format.name == format
        assertNdarraysEqual(frame.to_ndarray(), array)


def test_ndarray_gbrap12() -> None:
    array = numpy.random.randint(0, 4096, size=(480, 640, 4), dtype=numpy.uint16)
    for format in ("gbrap12be", "gbrap12le"):
        frame = VideoFrame.from_ndarray(array, format=format)
        assert format in supported_np_pix_fmts
        assert frame.width == 640 and frame.height == 480
        assert frame.format.name == format
        assertNdarraysEqual(frame.to_ndarray(), array)


def test_ndarray_gbrap12_align() -> None:
    array = numpy.random.randint(0, 4096, size=(238, 318, 4), dtype=numpy.uint16)
    for format in ("gbrap12be", "gbrap12le"):
        frame = VideoFrame.from_ndarray(array, format=format)
        assert format in supported_np_pix_fmts
        assert frame.width == 318 and frame.height == 238
        assert frame.format.name == format
        assertNdarraysEqual(frame.to_ndarray(), array)


def test_ndarray_gbrap14() -> None:
    array = numpy.random.randint(0, 16384, size=(480, 640, 4), dtype=numpy.uint16)
    for format in ("gbrap14be", "gbrap14le"):
        frame = VideoFrame.from_ndarray(array, format=format)
        assert format in supported_np_pix_fmts
        assert frame.width == 640 and frame.height == 480
        assert frame.format.name == format
        assertNdarraysEqual(frame.to_ndarray(), array)


def test_ndarray_gbrap14_align() -> None:
    array = numpy.random.randint(0, 16384, size=(238, 318, 4), dtype=numpy.uint16)
    for format in ("gbrap14be", "gbrap14le"):
        frame = VideoFrame.from_ndarray(array, format=format)
        assert format in supported_np_pix_fmts
        assert frame.width == 318 and frame.height == 238
        assert frame.format.name == format
        assertNdarraysEqual(frame.to_ndarray(), array)


def test_ndarray_gbrap16() -> None:
    array = numpy.random.randint(0, 65536, size=(480, 640, 4), dtype=numpy.uint16)
    for format in ("gbrap16be", "gbrap16le"):
        frame = VideoFrame.from_ndarray(array, format=format)
        assert format in supported_np_pix_fmts
        assert frame.width == 640 and frame.height == 480
        assert frame.format.name == format
        assertNdarraysEqual(frame.to_ndarray(), array)


def test_ndarray_gbrap16_align() -> None:
    array = numpy.random.randint(0, 65536, size=(238, 318, 4), dtype=numpy.uint16)
    for format in ("gbrap16be", "gbrap16le"):
        frame = VideoFrame.from_ndarray(array, format=format)
        assert format in supported_np_pix_fmts
        assert frame.width == 318 and frame.height == 238
        assert frame.format.name == format
        assertNdarraysEqual(frame.to_ndarray(), array)


def test_ndarray_gbrapf32() -> None:
    array = numpy.random.random_sample(size=(480, 640, 4)).astype(numpy.float32)
    for format in ("gbrapf32be", "gbrapf32le"):
        frame = VideoFrame.from_ndarray(array, format=format)
        assert frame.width == 640 and frame.height == 480
        assert frame.format.name == format
        assertNdarraysEqual(frame.to_ndarray(), array)


def test_ndarray_gbrapf32_align() -> None:
    array = numpy.random.random_sample(size=(238, 318, 4)).astype(numpy.float32)
    for format in ("gbrapf32be", "gbrapf32le"):
        frame = VideoFrame.from_ndarray(array, format=format)
        assert frame.width == 318 and frame.height == 238
        assert frame.format.name == format
        assertNdarraysEqual(frame.to_ndarray(), array)


def test_ndarray_gbrp() -> None:
    array = numpy.random.randint(0, 256, size=(480, 640, 3), dtype=numpy.uint8)
    frame = VideoFrame.from_ndarray(array, format="gbrp")
    assert frame.width == 640 and frame.height == 480
    assert frame.format.name == "gbrp"
    assertNdarraysEqual(frame.to_ndarray(), array)


def test_ndarray_gbrp_align() -> None:
    array = numpy.random.randint(0, 256, size=(238, 318, 3), dtype=numpy.uint8)
    frame = VideoFrame.from_ndarray(array, format="gbrp")
    assert frame.width == 318 and frame.height == 238
    assert frame.format.name == "gbrp"
    assertNdarraysEqual(frame.to_ndarray(), array)


def test_ndarray_gbrp9() -> None:
    array = numpy.random.randint(0, 512, size=(480, 640, 3), dtype=numpy.uint16)
    for format in ("gbrp9be", "gbrp9le"):
        frame = VideoFrame.from_ndarray(array, format=format)
        assert format in supported_np_pix_fmts
        assert frame.width == 640 and frame.height == 480
        assert frame.format.name == format
        assertNdarraysEqual(frame.to_ndarray(), array)


def test_ndarray_gbrp9_align() -> None:
    array = numpy.random.randint(0, 512, size=(238, 318, 3), dtype=numpy.uint16)
    for format in ("gbrp9be", "gbrp9le"):
        frame = VideoFrame.from_ndarray(array, format=format)
        assert format in supported_np_pix_fmts
        assert frame.width == 318 and frame.height == 238
        assert frame.format.name == format
        assertNdarraysEqual(frame.to_ndarray(), array)


def test_ndarray_gbrp10() -> None:
    array = numpy.random.randint(0, 1024, size=(480, 640, 3), dtype=numpy.uint16)
    for format in ("gbrp10be", "gbrp10le"):
        frame = VideoFrame.from_ndarray(array, format=format)
        assert format in supported_np_pix_fmts
        assert frame.width == 640 and frame.height == 480
        assert frame.format.name == format
        assertNdarraysEqual(frame.to_ndarray(), array)


def test_ndarray_gbrp10_align() -> None:
    array = numpy.random.randint(0, 1024, size=(238, 318, 3), dtype=numpy.uint16)
    for format in ("gbrp10be", "gbrp10le"):
        frame = VideoFrame.from_ndarray(array, format=format)
        assert format in supported_np_pix_fmts
        assert frame.width == 318 and frame.height == 238
        assert frame.format.name == format
        assertNdarraysEqual(frame.to_ndarray(), array)


def test_ndarray_gbrp12() -> None:
    array = numpy.random.randint(0, 4096, size=(480, 640, 3), dtype=numpy.uint16)
    for format in ("gbrp12be", "gbrp12le"):
        frame = VideoFrame.from_ndarray(array, format=format)
        assert format in supported_np_pix_fmts
        assert frame.width == 640 and frame.height == 480
        assert frame.format.name == format
        assertNdarraysEqual(frame.to_ndarray(), array)


def test_ndarray_gbrp12_align() -> None:
    array = numpy.random.randint(0, 4096, size=(238, 318, 3), dtype=numpy.uint16)
    for format in ("gbrp12be", "gbrp12le"):
        frame = VideoFrame.from_ndarray(array, format=format)
        assert format in supported_np_pix_fmts
        assert frame.width == 318 and frame.height == 238
        assert frame.format.name == format
        assertNdarraysEqual(frame.to_ndarray(), array)


def test_ndarray_gbrp14() -> None:
    array = numpy.random.randint(0, 16384, size=(480, 640, 3), dtype=numpy.uint16)
    for format in ("gbrp14be", "gbrp14le"):
        frame = VideoFrame.from_ndarray(array, format=format)
        assert format in supported_np_pix_fmts
        assert frame.width == 640 and frame.height == 480
        assert frame.format.name == format
        assertNdarraysEqual(frame.to_ndarray(), array)


def test_ndarray_gbrp14_align() -> None:
    array = numpy.random.randint(0, 16384, size=(238, 318, 3), dtype=numpy.uint16)
    for format in ("gbrp14be", "gbrp14le"):
        frame = VideoFrame.from_ndarray(array, format=format)
        assert format in supported_np_pix_fmts
        assert frame.width == 318 and frame.height == 238
        assert frame.format.name == format
        assertNdarraysEqual(frame.to_ndarray(), array)


def test_ndarray_gbrp16() -> None:
    array = numpy.random.randint(0, 65536, size=(480, 640, 3), dtype=numpy.uint16)
    for format in ("gbrp16be", "gbrp16le"):
        frame = VideoFrame.from_ndarray(array, format=format)
        assert format in supported_np_pix_fmts
        assert frame.width == 640 and frame.height == 480
        assert frame.format.name == format
        assertNdarraysEqual(frame.to_ndarray(), array)


def test_ndarray_gbrp16_align() -> None:
    array = numpy.random.randint(0, 65536, size=(238, 318, 3), dtype=numpy.uint16)
    for format in ("gbrp16be", "gbrp16le"):
        frame = VideoFrame.from_ndarray(array, format=format)
        assert format in supported_np_pix_fmts
        assert frame.width == 318 and frame.height == 238
        assert frame.format.name == format
        assertNdarraysEqual(frame.to_ndarray(), array)


def test_ndarray_gbrpf32() -> None:
    array = numpy.random.random_sample(size=(480, 640, 3)).astype(numpy.float32)
    for format in ("gbrpf32be", "gbrpf32le"):
        frame = VideoFrame.from_ndarray(array, format=format)
        assert frame.width == 640 and frame.height == 480
        assert frame.format.name == format
        assertNdarraysEqual(frame.to_ndarray(), array)


def test_ndarray_gbrpf32_align() -> None:
    array = numpy.random.random_sample(size=(238, 318, 3)).astype(numpy.float32)
    for format in ["gbrpf32be", "gbrpf32le"]:
        frame = VideoFrame.from_ndarray(array, format=format)
        assert frame.width == 318 and frame.height == 238
        assert frame.format.name == format
        assertNdarraysEqual(frame.to_ndarray(), array)


def test_ndarray_yuv420p() -> None:
    array = numpy.random.randint(0, 256, size=(720, 640), dtype=numpy.uint8)
    frame = VideoFrame.from_ndarray(array, format="yuv420p")
    assert frame.width == 640 and frame.height == 480
    assert frame.format.name == "yuv420p"
    assertNdarraysEqual(frame.to_ndarray(), array)


def test_ndarray_yuv420p_align() -> None:
    array = numpy.random.randint(0, 256, size=(357, 318), dtype=numpy.uint8)
    frame = VideoFrame.from_ndarray(array, format="yuv420p")
    assert frame.width == 318 and frame.height == 238
    assert frame.format.name == "yuv420p"
    assertNdarraysEqual(frame.to_ndarray(), array)


def test_ndarray_yuvj420p() -> None:
    array = numpy.random.randint(0, 256, size=(720, 640), dtype=numpy.uint8)
    frame = VideoFrame.from_ndarray(array, format="yuvj420p")
    assert frame.width == 640 and frame.height == 480
    assert frame.format.name == "yuvj420p"
    assertNdarraysEqual(frame.to_ndarray(), array)


def test_ndarray_yuyv422() -> None:
    array = numpy.random.randint(0, 256, size=(480, 640, 2), dtype=numpy.uint8)
    frame = VideoFrame.from_ndarray(array, format="yuyv422")
    assert frame.width == 640 and frame.height == 480
    assert frame.format.name == "yuyv422"
    assertNdarraysEqual(frame.to_ndarray(), array)


def test_ndarray_yuv444p() -> None:
    array = numpy.random.randint(0, 256, size=(3, 480, 640), dtype=numpy.uint8)
    frame = VideoFrame.from_ndarray(array, format="yuv444p")
    assert frame.width == 640 and frame.height == 480
    assert frame.format.name == "yuv444p"
    assertNdarraysEqual(frame.to_ndarray(), array)

    array = numpy.random.randint(0, 256, size=(3, 480, 640), dtype=numpy.uint8)
    frame = VideoFrame.from_ndarray(array, channel_last=False, format="yuv444p")
    assert frame.width == 640 and frame.height == 480
    assert frame.format.name == "yuv444p"
    assertNdarraysEqual(frame.to_ndarray(channel_last=False), array)
    assert array.shape != frame.to_ndarray(channel_last=True).shape
    assert (
        frame.to_ndarray(channel_last=False).shape
        != frame.to_ndarray(channel_last=True).shape
    )


def test_ndarray_yuvj444p() -> None:
    array = numpy.random.randint(0, 256, size=(3, 480, 640), dtype=numpy.uint8)
    frame = VideoFrame.from_ndarray(array, format="yuvj444p")
    assert frame.width == 640 and frame.height == 480
    assert frame.format.name == "yuvj444p"
    assertNdarraysEqual(frame.to_ndarray(), array)


def test_ndarray_yuv444p16() -> None:
    array = numpy.random.randint(0, 65536, size=(480, 640, 3), dtype=numpy.uint16)
    for format in ("yuv444p16be", "yuv444p16le"):
        frame = VideoFrame.from_ndarray(array, format=format)
        assert frame.width == 640 and frame.height == 480
        assert frame.format.name == format
        assertNdarraysEqual(frame.to_ndarray(), array)


def test_ndarray_yuv422p10le() -> None:
    array = numpy.random.randint(0, 65536, size=(3, 480, 640), dtype=numpy.uint16)
    for format in ("yuv422p10le",):
        frame = VideoFrame.from_ndarray(array, format=format)
        assert frame.width == 640 and frame.height == 480
        assert frame.format.name == format
        assert format in supported_np_pix_fmts


def test_ndarray_yuv444p16_align() -> None:
    array = numpy.random.randint(0, 65536, size=(238, 318, 3), dtype=numpy.uint16)
    for format in ("yuv444p16be", "yuv444p16le"):
        frame = VideoFrame.from_ndarray(array, format=format)
        assert frame.width == 318 and frame.height == 238
        assert frame.format.name == format
        assertNdarraysEqual(frame.to_ndarray(), array)


def test_ndarray_yuva444p16() -> None:
    array = numpy.random.randint(0, 65536, size=(480, 640, 4), dtype=numpy.uint16)
    for format in ("yuva444p16be", "yuva444p16le"):
        frame = VideoFrame.from_ndarray(array, format=format)
        assert frame.width == 640 and frame.height == 480
        assert frame.format.name == format
        assertNdarraysEqual(frame.to_ndarray(), array)


def test_ndarray_yuva444p16_align() -> None:
    array = numpy.random.randint(0, 65536, size=(238, 318, 4), dtype=numpy.uint16)
    for format in ("yuva444p16be", "yuva444p16le"):
        frame = VideoFrame.from_ndarray(array, format=format)
        assert frame.width == 318 and frame.height == 238
        assert frame.format.name == format
        assertNdarraysEqual(frame.to_ndarray(), array)


def test_ndarray_yuyv422_align() -> None:
    array = numpy.random.randint(0, 256, size=(238, 318, 2), dtype=numpy.uint8)
    frame = VideoFrame.from_ndarray(array, format="yuyv422")
    assert frame.width == 318 and frame.height == 238
    assert frame.format.name == "yuyv422"
    assertNdarraysEqual(frame.to_ndarray(), array)


def test_ndarray_rgb48be() -> None:
    array = numpy.random.randint(0, 65536, size=(480, 640, 3), dtype=numpy.uint16)
    frame = VideoFrame.from_ndarray(array, format="rgb48be")
    assert frame.width == 640 and frame.height == 480
    assert frame.format.name == "rgb48be"
    assertNdarraysEqual(frame.to_ndarray(), array)

    # check endianness by examining red value of first pixel
    assertPixelValue16(frame.planes[0], array[0][0][0], "big")


def test_ndarray_bgr48be() -> None:
    array = numpy.random.randint(0, 65536, size=(480, 640, 3), dtype=numpy.uint16)
    frame = VideoFrame.from_ndarray(array, format="bgr48be")
    assert frame.width == 640 and frame.height == 480
    assert frame.format.name == "bgr48be"
    assertNdarraysEqual(frame.to_ndarray(), array)

    # check endianness by examining blue value of first pixel
    assertPixelValue16(frame.planes[0], array[0][0][0], "big")


def test_ndarray_rgb48le() -> None:
    array = numpy.random.randint(0, 65536, size=(480, 640, 3), dtype=numpy.uint16)
    frame = VideoFrame.from_ndarray(array, format="rgb48le")
    assert frame.width == 640 and frame.height == 480
    assert frame.format.name == "rgb48le"
    assertNdarraysEqual(frame.to_ndarray(), array)

    # check endianness by examining red value of first pixel
    assertPixelValue16(frame.planes[0], array[0][0][0], "little")


def test_ndarray_bgr48le() -> None:
    array = numpy.random.randint(0, 65536, size=(480, 640, 3), dtype=numpy.uint16)
    frame = VideoFrame.from_ndarray(array, format="bgr48le")
    assert frame.width == 640 and frame.height == 480
    assert frame.format.name == "bgr48le"
    assertNdarraysEqual(frame.to_ndarray(), array)

    # check endianness by examining blue value of first pixel
    assertPixelValue16(frame.planes[0], array[0][0][0], "little")


def test_ndarray_rgb48le_align() -> None:
    array = numpy.random.randint(0, 65536, size=(238, 318, 3), dtype=numpy.uint16)
    frame = VideoFrame.from_ndarray(array, format="rgb48le")
    assert frame.width == 318 and frame.height == 238
    assert frame.format.name == "rgb48le"
    assertNdarraysEqual(frame.to_ndarray(), array)

    # check endianness by examining red value of first pixel
    assertPixelValue16(frame.planes[0], array[0][0][0], "little")


def test_ndarray_bgr48le_align() -> None:
    array = numpy.random.randint(0, 65536, size=(238, 318, 3), dtype=numpy.uint16)
    frame = VideoFrame.from_ndarray(array, format="bgr48le")
    assert frame.width == 318 and frame.height == 238
    assert frame.format.name == "bgr48le"
    assertNdarraysEqual(frame.to_ndarray(), array)

    # check endianness by examining blue value of first pixel
    assertPixelValue16(frame.planes[0], array[0][0][0], "little")


def test_ndarray_rgba64be() -> None:
    array = numpy.random.randint(0, 65536, size=(480, 640, 4), dtype=numpy.uint16)
    frame = VideoFrame.from_ndarray(array, format="rgba64be")
    assert frame.width == 640 and frame.height == 480
    assert frame.format.name == "rgba64be"
    assertNdarraysEqual(frame.to_ndarray(), array)

    # check endianness by examining red value of first pixel
    assertPixelValue16(frame.planes[0], array[0][0][0], "big")


def test_ndarray_bgra64be() -> None:
    array = numpy.random.randint(0, 65536, size=(480, 640, 4), dtype=numpy.uint16)
    frame = VideoFrame.from_ndarray(array, format="bgra64be")
    assert frame.width == 640 and frame.height == 480
    assert frame.format.name == "bgra64be"
    assertNdarraysEqual(frame.to_ndarray(), array)

    # check endianness by examining blue value of first pixel
    assertPixelValue16(frame.planes[0], array[0][0][0], "big")


def test_ndarray_rgba64le() -> None:
    array = numpy.random.randint(0, 65536, size=(480, 640, 4), dtype=numpy.uint16)
    frame = VideoFrame.from_ndarray(array, format="rgba64le")
    assert frame.width == 640 and frame.height == 480
    assert frame.format.name == "rgba64le"
    assertNdarraysEqual(frame.to_ndarray(), array)

    # check endianness by examining red value of first pixel
    assertPixelValue16(frame.planes[0], array[0][0][0], "little")


def test_ndarray_bgra64le() -> None:
    array = numpy.random.randint(0, 65536, size=(480, 640, 4), dtype=numpy.uint16)
    frame = VideoFrame.from_ndarray(array, format="bgra64le")
    assert frame.width == 640 and frame.height == 480
    assert frame.format.name == "bgra64le"
    assertNdarraysEqual(frame.to_ndarray(), array)

    # check endianness by examining blue value of first pixel
    assertPixelValue16(frame.planes[0], array[0][0][0], "little")


def test_ndarray_rgbaf16() -> None:
    array = numpy.random.random_sample(size=(480, 640, 4)).astype(numpy.float16)
    for format in ("rgbaf16be", "rgbaf16le"):
        frame = VideoFrame.from_ndarray(array, format=format)
        assert frame.width == 640 and frame.height == 480
        assert frame.format.name == format
        assertNdarraysEqual(frame.to_ndarray(), array)


def test_ndarray_rgbaf32() -> None:
    array = numpy.random.random_sample(size=(480, 640, 4)).astype(numpy.float32)
    for format in ("rgbaf32be", "rgbaf32le"):
        frame = VideoFrame.from_ndarray(array, format=format)
        assert frame.width == 640 and frame.height == 480
        assert frame.format.name == format
        assertNdarraysEqual(frame.to_ndarray(), array)


def test_ndarray_rgb8() -> None:
    array = numpy.random.randint(0, 256, size=(480, 640), dtype=numpy.uint8)
    frame = VideoFrame.from_ndarray(array, format="rgb8")
    assert frame.width == 640 and frame.height == 480
    assert frame.format.name == "rgb8"
    assertNdarraysEqual(frame.to_ndarray(), array)


def test_ndarray_bgr8() -> None:
    array = numpy.random.randint(0, 256, size=(480, 640), dtype=numpy.uint8)
    frame = VideoFrame.from_ndarray(array, format="bgr8")
    assert frame.width == 640 and frame.height == 480
    assert frame.format.name == "bgr8"
    assertNdarraysEqual(frame.to_ndarray(), array)


def test_ndarray_pal8():
    array = numpy.random.randint(0, 256, size=(480, 640), dtype=numpy.uint8)
    palette = numpy.random.randint(0, 256, size=(256, 4), dtype=numpy.uint8)
    frame = VideoFrame.from_ndarray((array, palette), format="pal8")
    assert frame.width == 640 and frame.height == 480
    assert frame.format.name == "pal8"
    assert frame.format.name in supported_np_pix_fmts
    returned = frame.to_ndarray()
    assert type(returned) is tuple and len(returned) == 2
    assertNdarraysEqual(returned[0], array)
    assertNdarraysEqual(returned[1], palette)


def test_ndarray_nv12() -> None:
    array = numpy.random.randint(0, 256, size=(720, 640), dtype=numpy.uint8)
    frame = VideoFrame.from_ndarray(array, format="nv12")
    assert frame.width == 640 and frame.height == 480
    assert frame.format.name == "nv12"
    assert frame.format.name in supported_np_pix_fmts
    assertNdarraysEqual(frame.to_ndarray(), array)


def test_ndarray_nv12_align() -> None:
    array = numpy.random.randint(0, 256, size=(357, 318), dtype=numpy.uint8)
    frame = VideoFrame.from_ndarray(array, format="nv12")
    assert frame.width == 318 and frame.height == 238
    assert frame.format.name == "nv12"
    assertNdarraysEqual(frame.to_ndarray(), array)


def test_shares_memory_gray() -> None:
    array = numpy.random.randint(0, 256, size=(357, 318), dtype=numpy.uint8)
    frame = VideoFrame.from_numpy_buffer(array, "gray")
    assertNdarraysEqual(frame.to_ndarray(), array)

    # overwrite the array, the contents thereof
    array[...] = numpy.random.randint(0, 256, size=(357, 318), dtype=numpy.uint8)
    # Make sure the frame reflects that
    assertNdarraysEqual(frame.to_ndarray(), array)

    # repeat the test, but with an array that is not fully contiguous, though the
    # pixels in a row are
    array = numpy.random.randint(0, 256, size=(357, 318), dtype=numpy.uint8)
    array = array[:, :300]
    assert not array.data.c_contiguous
    frame = VideoFrame.from_numpy_buffer(array, "gray")
    assertNdarraysEqual(frame.to_ndarray(), array)

    # overwrite the array, the contents thereof
    array[...] = numpy.random.randint(0, 256, size=array.shape, dtype=numpy.uint8)
    # Make sure the frame reflects that
    assertNdarraysEqual(frame.to_ndarray(), array)


def test_shares_memory_gray8() -> None:
    array = numpy.random.randint(0, 256, size=(357, 318), dtype=numpy.uint8)
    frame = VideoFrame.from_numpy_buffer(array, "gray8")
    assertNdarraysEqual(frame.to_ndarray(), array)

    # overwrite the array, the contents thereof
    array[...] = numpy.random.randint(0, 256, size=(357, 318), dtype=numpy.uint8)
    # Make sure the frame reflects that
    assertNdarraysEqual(frame.to_ndarray(), array)

    # repeat the test, but with an array that is not fully contiguous, though the
    # pixels in a row are
    array = numpy.random.randint(0, 256, size=(357, 318), dtype=numpy.uint8)
    array = array[:, :300]
    assert not array.data.c_contiguous
    frame = VideoFrame.from_numpy_buffer(array, "gray8")
    assertNdarraysEqual(frame.to_ndarray(), array)

    # overwrite the array, the contents thereof
    array[...] = numpy.random.randint(0, 256, size=array.shape, dtype=numpy.uint8)
    # Make sure the frame reflects that
    assertNdarraysEqual(frame.to_ndarray(), array)


def test_shares_memory_rgb8() -> None:
    array = numpy.random.randint(0, 256, size=(357, 318), dtype=numpy.uint8)
    frame = VideoFrame.from_numpy_buffer(array, "rgb8")
    assertNdarraysEqual(frame.to_ndarray(), array)

    # overwrite the array, the contents thereof
    array[...] = numpy.random.randint(0, 256, size=(357, 318), dtype=numpy.uint8)
    # Make sure the frame reflects that
    assertNdarraysEqual(frame.to_ndarray(), array)

    # repeat the test, but with an array that is not fully contiguous, though the
    # pixels in a row are
    array = numpy.random.randint(0, 256, size=(357, 318), dtype=numpy.uint8)
    array = array[:, :300]
    assert not array.data.c_contiguous
    frame = VideoFrame.from_numpy_buffer(array, "rgb8")
    assertNdarraysEqual(frame.to_ndarray(), array)

    # overwrite the array, the contents thereof
    array[...] = numpy.random.randint(0, 256, size=array.shape, dtype=numpy.uint8)
    # Make sure the frame reflects that
    assertNdarraysEqual(frame.to_ndarray(), array)


def test_shares_memory_bgr8() -> None:
    array = numpy.random.randint(0, 256, size=(357, 318), dtype=numpy.uint8)
    frame = VideoFrame.from_numpy_buffer(array, "bgr8")
    assertNdarraysEqual(frame.to_ndarray(), array)

    # overwrite the array, the contents thereof
    array[...] = numpy.random.randint(0, 256, size=(357, 318), dtype=numpy.uint8)
    # Make sure the frame reflects that
    assertNdarraysEqual(frame.to_ndarray(), array)

    # repeat the test, but with an array that is not fully contiguous, though the
    # pixels in a row are
    array = numpy.random.randint(0, 256, size=(357, 318), dtype=numpy.uint8)
    array = array[:, :300]
    assert not array.data.c_contiguous
    frame = VideoFrame.from_numpy_buffer(array, "bgr8")
    assertNdarraysEqual(frame.to_ndarray(), array)

    # overwrite the array, the contents thereof
    array[...] = numpy.random.randint(0, 256, size=array.shape, dtype=numpy.uint8)
    # Make sure the frame reflects that
    assertNdarraysEqual(frame.to_ndarray(), array)


def test_shares_memory_rgb24() -> None:
    array = numpy.random.randint(0, 256, size=(357, 318, 3), dtype=numpy.uint8)
    frame = VideoFrame.from_numpy_buffer(array, "rgb24")
    assertNdarraysEqual(frame.to_ndarray(), array)

    # overwrite the array, the contents thereof
    array[...] = numpy.random.randint(0, 256, size=(357, 318, 3), dtype=numpy.uint8)
    # Make sure the frame reflects that
    assertNdarraysEqual(frame.to_ndarray(), array)

    # repeat the test, but with an array that is not fully contiguous, though the
    # pixels in a row are
    array = numpy.random.randint(0, 256, size=(357, 318, 3), dtype=numpy.uint8)
    array = array[:, :300, :]
    assert not array.data.c_contiguous
    frame = VideoFrame.from_numpy_buffer(array, "rgb24")
    assertNdarraysEqual(frame.to_ndarray(), array)

    # overwrite the array, the contents thereof
    array[...] = numpy.random.randint(0, 256, size=array.shape, dtype=numpy.uint8)
    # Make sure the frame reflects that
    assertNdarraysEqual(frame.to_ndarray(), array)


def test_shares_memory_rgba() -> None:
    array = numpy.random.randint(0, 256, size=(357, 318, 4), dtype=numpy.uint8)
    frame = VideoFrame.from_numpy_buffer(array, "rgba")
    assertNdarraysEqual(frame.to_ndarray(), array)

    # overwrite the array, the contents thereof
    array[...] = numpy.random.randint(0, 256, size=(357, 318, 4), dtype=numpy.uint8)
    # Make sure the frame reflects that
    assertNdarraysEqual(frame.to_ndarray(), array)

    # repeat the test, but with an array that is not fully contiguous, though the
    # pixels in a row are
    array = numpy.random.randint(0, 256, size=(357, 318, 4), dtype=numpy.uint8)
    array = array[:, :300, :]
    assert not array.data.c_contiguous
    frame = VideoFrame.from_numpy_buffer(array, "rgba")
    assertNdarraysEqual(frame.to_ndarray(), array)

    # overwrite the array, the contents thereof
    array[...] = numpy.random.randint(0, 256, size=array.shape, dtype=numpy.uint8)
    # Make sure the frame reflects that
    assertNdarraysEqual(frame.to_ndarray(), array)


def test_shares_memory_bayer8() -> None:
    for format in ("bayer_rggb8", "bayer_bggr8", "bayer_grbg8", "bayer_gbrg8"):
        array = numpy.random.randint(0, 256, size=(357, 318), dtype=numpy.uint8)
        frame = VideoFrame.from_numpy_buffer(array, format)
        assertNdarraysEqual(frame.to_ndarray(), array)

        array[...] = numpy.random.randint(0, 256, size=(357, 318), dtype=numpy.uint8)
        assertNdarraysEqual(frame.to_ndarray(), array)

        array = numpy.random.randint(0, 256, size=(357, 318), dtype=numpy.uint8)
        array = array[:, :300]
        assert not array.data.c_contiguous
        frame = VideoFrame.from_numpy_buffer(array, format)
        assertNdarraysEqual(frame.to_ndarray(), array)

        array[...] = numpy.random.randint(0, 256, size=array.shape, dtype=numpy.uint8)
        assertNdarraysEqual(frame.to_ndarray(), array)


def test_shares_memory_yuv420p() -> None:
    array = numpy.random.randint(0, 256, size=(512 * 6 // 4, 256), dtype=numpy.uint8)
    frame = VideoFrame.from_numpy_buffer(array, "yuv420p")
    assertNdarraysEqual(frame.to_ndarray(), array)

    # overwrite the array, the contents thereof
    array[...] = numpy.random.randint(0, 256, size=array.shape, dtype=numpy.uint8)
    # Make sure the frame reflects that
    assertNdarraysEqual(frame.to_ndarray(), array)

    # repeat the test, but with an array where there are some padding bytes
    # note that the uv rows have half the padding in the middle of a row, and the
    # other half at the end
    height = 512
    stride = 256
    width = 200
    array = numpy.random.randint(
        0, 256, size=(height * 6 // 4, stride), dtype=numpy.uint8
    )
    uv_width = width // 2
    uv_stride = stride // 2

    # compare carefully, avoiding all the padding bytes which to_ndarray strips out
    frame = VideoFrame.from_numpy_buffer(array, "yuv420p", width=width)
    frame_array = frame.to_ndarray()
    assertNdarraysEqual(frame_array[:height, :width], array[:height, :width])
    assertNdarraysEqual(frame_array[height:, :uv_width], array[height:, :uv_width])
    assertNdarraysEqual(
        frame_array[height:, uv_width:],
        array[height:, uv_stride : uv_stride + uv_width],
    )

    # overwrite the array, and check the shared frame buffer changed too!
    array[...] = numpy.random.randint(0, 256, size=array.shape, dtype=numpy.uint8)
    frame_array = frame.to_ndarray()
    assertNdarraysEqual(frame_array[:height, :width], array[:height, :width])
    assertNdarraysEqual(frame_array[height:, :uv_width], array[height:, :uv_width])
    assertNdarraysEqual(
        frame_array[height:, uv_width:],
        array[height:, uv_stride : uv_stride + uv_width],
    )


def test_shares_memory_yuvj420p() -> None:
    array = numpy.random.randint(0, 256, size=(512 * 6 // 4, 256), dtype=numpy.uint8)
    frame = VideoFrame.from_numpy_buffer(array, "yuvj420p")
    assertNdarraysEqual(frame.to_ndarray(), array)

    # overwrite the array, the contents thereof
    array[...] = numpy.random.randint(0, 256, size=array.shape, dtype=numpy.uint8)
    # Make sure the frame reflects that
    assertNdarraysEqual(frame.to_ndarray(), array)

    # repeat the test with padding, just as we did in the yuv420p case
    height = 512
    stride = 256
    width = 200
    array = numpy.random.randint(
        0, 256, size=(height * 6 // 4, stride), dtype=numpy.uint8
    )
    uv_width = width // 2
    uv_stride = stride // 2

    # compare carefully, avoiding all the padding bytes which to_ndarray strips out
    frame = VideoFrame.from_numpy_buffer(array, "yuvj420p", width=width)
    frame_array = frame.to_ndarray()
    assertNdarraysEqual(frame_array[:height, :width], array[:height, :width])
    assertNdarraysEqual(frame_array[height:, :uv_width], array[height:, :uv_width])
    assertNdarraysEqual(
        frame_array[height:, uv_width:],
        array[height:, uv_stride : uv_stride + uv_width],
    )

    # overwrite the array, and check the shared frame buffer changed too!
    array[...] = numpy.random.randint(0, 256, size=array.shape, dtype=numpy.uint8)
    frame_array = frame.to_ndarray()
    assertNdarraysEqual(frame_array[:height, :width], array[:height, :width])
    assertNdarraysEqual(frame_array[height:, :uv_width], array[height:, :uv_width])
    assertNdarraysEqual(
        frame_array[height:, uv_width:],
        array[height:, uv_stride : uv_stride + uv_width],
    )


def test_shares_memory_nv12() -> None:
    array = numpy.random.randint(0, 256, size=(512 * 6 // 4, 256), dtype=numpy.uint8)
    frame = VideoFrame.from_numpy_buffer(array, "nv12")
    assertNdarraysEqual(frame.to_ndarray(), array)

    # overwrite the array, the contents thereof
    array[...] = numpy.random.randint(0, 256, size=array.shape, dtype=numpy.uint8)
    # Make sure the frame reflects that
    assertNdarraysEqual(frame.to_ndarray(), array)

    # repeat the test, but with an array that is not fully contiguous, though the
    # pixels in a row are
    array = numpy.random.randint(0, 256, size=(512 * 6 // 4, 256), dtype=numpy.uint8)
    array = array[:, :200]
    assert not array.data.c_contiguous
    frame = VideoFrame.from_numpy_buffer(array, "nv12")
    assertNdarraysEqual(frame.to_ndarray(), array)

    # overwrite the array, the contents thereof
    array[...] = numpy.random.randint(0, 256, size=array.shape, dtype=numpy.uint8)
    # Make sure the frame reflects that
    assertNdarraysEqual(frame.to_ndarray(), array)


def test_shares_memory_bgr24() -> None:
    array = numpy.random.randint(0, 256, size=(357, 318, 3), dtype=numpy.uint8)
    frame = VideoFrame.from_numpy_buffer(array, "bgr24")
    assertNdarraysEqual(frame.to_ndarray(), array)

    # overwrite the array, the contents thereof
    array[...] = numpy.random.randint(0, 256, size=(357, 318, 3), dtype=numpy.uint8)
    # Make sure the frame reflects that
    assertNdarraysEqual(frame.to_ndarray(), array)

    # repeat the test, but with an array that is not fully contiguous, though the
    # pixels in a row are
    array = numpy.random.randint(0, 256, size=(357, 318, 3), dtype=numpy.uint8)
    array = array[:, :300, :]
    assert not array.data.c_contiguous
    frame = VideoFrame.from_numpy_buffer(array, "bgr24")
    assertNdarraysEqual(frame.to_ndarray(), array)

    # overwrite the array, the contents thereof
    array[...] = numpy.random.randint(0, 256, size=array.shape, dtype=numpy.uint8)
    # Make sure the frame reflects that
    assertNdarraysEqual(frame.to_ndarray(), array)


def test_shares_memory_bgra() -> None:
    array = numpy.random.randint(0, 256, size=(357, 318, 4), dtype=numpy.uint8)
    frame = VideoFrame.from_numpy_buffer(array, "bgra")
    assertNdarraysEqual(frame.to_ndarray(), array)

    # overwrite the array, the contents thereof
    array[...] = numpy.random.randint(0, 256, size=(357, 318, 4), dtype=numpy.uint8)
    # Make sure the frame reflects that
    assertNdarraysEqual(frame.to_ndarray(), array)

    # repeat the test, but with an array that is not fully contiguous, though the
    # pixels in a row are
    array = numpy.random.randint(0, 256, size=(357, 318, 4), dtype=numpy.uint8)
    array = array[:, :300, :]
    assert not array.data.c_contiguous
    frame = VideoFrame.from_numpy_buffer(array, "bgra")
    assertNdarraysEqual(frame.to_ndarray(), array)

    # overwrite the array, the contents thereof
    array[...] = numpy.random.randint(0, 256, size=array.shape, dtype=numpy.uint8)
    # Make sure the frame reflects that
    assertNdarraysEqual(frame.to_ndarray(), array)


def test_reformat_pts() -> None:
    frame = VideoFrame(640, 480, "rgb24")
    frame.pts = 123
    frame.time_base = Fraction("456/1")
    frame = frame.reformat(320, 240)
    assert frame.pts == 123 and frame.time_base == 456


def test_reformat_identity() -> None:
    frame1 = VideoFrame(640, 480, "rgb24")
    frame2 = frame1.reformat(640, 480, "rgb24")
    assert frame1 is frame2


def test_reformat_colorspace() -> None:
    frame = VideoFrame(640, 480, "rgb24")
    frame.reformat(src_colorspace=None, dst_colorspace="smpte240m")

    frame = VideoFrame(640, 480, "rgb24")
    frame.reformat(src_colorspace=None, dst_colorspace=Colorspace.smpte240m)

    frame = VideoFrame(640, 480, "yuv420p")
    frame.reformat(src_colorspace=None, dst_colorspace="smpte240m")

    frame = VideoFrame(640, 480, "rgb24")
    frame.colorspace = Colorspace.smpte240m
    assert frame.colorspace == int(Colorspace.smpte240m)
    assert frame.colorspace == Colorspace.smpte240m


def test_reformat_pixel_format_align() -> None:
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
        assertNdarraysEqual(frame_rgb.to_ndarray(), expected_rgb)
