from re import escape

import numpy as np
import pytest

from av import AudioFrame

from .common import assertNdarraysEqual


def test_null_constructor() -> None:
    frame = AudioFrame()
    assert frame.format.name == "s16"
    assert frame.layout.name == "stereo"
    assert len(frame.planes) == 0
    assert frame.samples == 0


def test_manual_flt_mono_constructor() -> None:
    frame = AudioFrame(format="flt", layout="mono", samples=160)
    assert frame.format.name == "flt"
    assert frame.layout.name == "mono"
    assert len(frame.planes) == 1
    assert frame.planes[0].buffer_size == 640
    assert frame.samples == 160


def test_manual_flt_stereo_constructor() -> None:
    frame = AudioFrame(format="flt", layout="stereo", samples=160)
    assert frame.format.name == "flt"
    assert frame.layout.name == "stereo"
    assert len(frame.planes) == 1
    assert frame.planes[0].buffer_size == 1280
    assert frame.samples == 160


def test_manual_fltp_stereo_constructor() -> None:
    frame = AudioFrame(format="fltp", layout="stereo", samples=160)
    assert frame.format.name == "fltp"
    assert frame.layout.name == "stereo"
    assert len(frame.planes) == 2
    assert frame.planes[0].buffer_size == 640
    assert frame.planes[1].buffer_size == 640
    assert frame.samples == 160


def test_manual_s16_mono_constructor() -> None:
    frame = AudioFrame(format="s16", layout="mono", samples=160)
    assert frame.format.name == "s16"
    assert frame.layout.name == "mono"
    assert len(frame.planes) == 1
    assert frame.planes[0].buffer_size == 320
    assert frame.samples == 160


def test_manual_s16_mono_constructor_align_8() -> None:
    frame = AudioFrame(format="s16", layout="mono", samples=159, align=8)
    assert frame.format.name == "s16"
    assert frame.layout.name == "mono"
    assert len(frame.planes) == 1
    assert frame.planes[0].buffer_size == 320
    assert frame.samples == 159


def test_manual_s16_stereo_constructor() -> None:
    frame = AudioFrame(format="s16", layout="stereo", samples=160)
    assert frame.format.name == "s16"
    assert frame.layout.name == "stereo"
    assert len(frame.planes) == 1
    assert frame.planes[0].buffer_size == 640
    assert frame.samples == 160


def test_manual_s16p_stereo_constructor() -> None:
    frame = AudioFrame(format="s16p", layout="stereo", samples=160)
    assert frame.format.name == "s16p"
    assert frame.layout.name == "stereo"
    assert len(frame.planes) == 2
    assert frame.planes[0].buffer_size == 320
    assert frame.planes[1].buffer_size == 320
    assert frame.samples == 160


def test_basic_to_ndarray() -> None:
    frame = AudioFrame(format="s16p", layout="stereo", samples=160)
    array = frame.to_ndarray()
    assert array.dtype == "i2"
    assert array.shape == (2, 160)


def test_ndarray_dbl() -> None:
    layouts = [
        ("dbl", "mono", (1, 160)),
        ("dbl", "stereo", (1, 320)),
        ("dblp", "mono", (1, 160)),
        ("dblp", "stereo", (2, 160)),
    ]
    for format, layout, size in layouts:
        array = np.zeros(shape=size, dtype="f8")
        for i in range(size[0]):
            array[i][:] = np.random.rand(size[1])
        frame = AudioFrame.from_ndarray(array, format=format, layout=layout)
        assert frame.format.name == format
        assert frame.layout.name == layout
        assert frame.samples == 160
        assertNdarraysEqual(frame.to_ndarray(), array)


def test_from_ndarray_value_error() -> None:
    # incorrect dtype
    array = np.zeros(shape=(1, 160), dtype="f2")
    with pytest.raises(
        ValueError, match="Expected numpy array with dtype `float32` but got `float16`"
    ) as cm:
        AudioFrame.from_ndarray(array, format="flt", layout="mono")

    # incorrect number of dimensions
    array = np.zeros(shape=(1, 160, 2), dtype="f4")
    with pytest.raises(
        ValueError, match="Expected numpy array with ndim `2` but got `3`"
    ) as cm:
        AudioFrame.from_ndarray(array, format="flt", layout="mono")

    # incorrect shape
    array = np.zeros(shape=(2, 160), dtype="f4")
    with pytest.raises(
        ValueError,
        match=escape("Expected packed `array.shape[0]` to equal `1` but got `2`"),
    ) as cm:
        AudioFrame.from_ndarray(array, format="flt", layout="mono")


def test_ndarray_flt() -> None:
    layouts = [
        ("flt", "mono", (1, 160)),
        ("flt", "stereo", (1, 320)),
        ("fltp", "mono", (1, 160)),
        ("fltp", "stereo", (2, 160)),
    ]
    for format, layout, size in layouts:
        array: np.ndarray = np.zeros(shape=size, dtype="f4")
        for i in range(size[0]):
            array[i][:] = np.random.rand(size[1])
        frame = AudioFrame.from_ndarray(array, format=format, layout=layout)
        assert frame.format.name == format
        assert frame.layout.name == layout
        assert frame.samples == 160
        assertNdarraysEqual(frame.to_ndarray(), array)


def test_ndarray_s16() -> None:
    layouts = [
        ("s16", "mono", (1, 160)),
        ("s16", "stereo", (1, 320)),
        ("s16p", "mono", (1, 160)),
        ("s16p", "stereo", (2, 160)),
    ]
    for format, layout, size in layouts:
        array = np.random.randint(0, 256, size=size, dtype="i2")
        frame = AudioFrame.from_ndarray(array, format=format, layout=layout)
        assert frame.format.name == format
        assert frame.layout.name == layout
        assert frame.samples == 160
        assertNdarraysEqual(frame.to_ndarray(), array)


def test_ndarray_s16p_align_8() -> None:
    frame = AudioFrame(format="s16p", layout="stereo", samples=159, align=8)
    array = frame.to_ndarray()
    assert array.dtype == "i2"
    assert array.shape == (2, 159)


def test_ndarray_s32() -> None:
    layouts = [
        ("s32", "mono", (1, 160)),
        ("s32", "stereo", (1, 320)),
        ("s32p", "mono", (1, 160)),
        ("s32p", "stereo", (2, 160)),
    ]
    for format, layout, size in layouts:
        array = np.random.randint(0, 256, size=size, dtype="i4")
        frame = AudioFrame.from_ndarray(array, format=format, layout=layout)
        assert frame.format.name == format
        assert frame.layout.name == layout
        assert frame.samples == 160
        assertNdarraysEqual(frame.to_ndarray(), array)


def test_ndarray_u8() -> None:
    layouts = [
        ("u8", "mono", (1, 160)),
        ("u8", "stereo", (1, 320)),
        ("u8p", "mono", (1, 160)),
        ("u8p", "stereo", (2, 160)),
    ]
    for format, layout, size in layouts:
        array = np.random.randint(0, 256, size=size, dtype="u1")
        frame = AudioFrame.from_ndarray(array, format=format, layout=layout)
        assert frame.format.name == format
        assert frame.layout.name == layout
        assert frame.samples == 160
        assertNdarraysEqual(frame.to_ndarray(), array)
