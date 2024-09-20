import numpy as np

from av import AudioFrame

from .common import TestCase


class TestAudioFrameConstructors(TestCase):
    def test_null_constructor(self) -> None:
        frame = AudioFrame()
        self.assertEqual(frame.format.name, "s16")
        self.assertEqual(frame.layout.name, "stereo")
        self.assertEqual(len(frame.planes), 0)
        self.assertEqual(frame.samples, 0)

    def test_manual_flt_mono_constructor(self) -> None:
        frame = AudioFrame(format="flt", layout="mono", samples=160)
        self.assertEqual(frame.format.name, "flt")
        self.assertEqual(frame.layout.name, "mono")
        self.assertEqual(len(frame.planes), 1)
        self.assertEqual(frame.planes[0].buffer_size, 640)
        self.assertEqual(frame.samples, 160)

    def test_manual_flt_stereo_constructor(self) -> None:
        frame = AudioFrame(format="flt", layout="stereo", samples=160)
        self.assertEqual(frame.format.name, "flt")
        self.assertEqual(frame.layout.name, "stereo")
        self.assertEqual(len(frame.planes), 1)
        self.assertEqual(frame.planes[0].buffer_size, 1280)
        self.assertEqual(frame.samples, 160)

    def test_manual_fltp_stereo_constructor(self) -> None:
        frame = AudioFrame(format="fltp", layout="stereo", samples=160)
        self.assertEqual(frame.format.name, "fltp")
        self.assertEqual(frame.layout.name, "stereo")
        self.assertEqual(len(frame.planes), 2)
        self.assertEqual(frame.planes[0].buffer_size, 640)
        self.assertEqual(frame.planes[1].buffer_size, 640)
        self.assertEqual(frame.samples, 160)

    def test_manual_s16_mono_constructor(self) -> None:
        frame = AudioFrame(format="s16", layout="mono", samples=160)
        self.assertEqual(frame.format.name, "s16")
        self.assertEqual(frame.layout.name, "mono")
        self.assertEqual(len(frame.planes), 1)
        self.assertEqual(frame.planes[0].buffer_size, 320)
        self.assertEqual(frame.samples, 160)

    def test_manual_s16_mono_constructor_align_8(self) -> None:
        frame = AudioFrame(format="s16", layout="mono", samples=159, align=8)
        self.assertEqual(frame.format.name, "s16")
        self.assertEqual(frame.layout.name, "mono")
        self.assertEqual(len(frame.planes), 1)
        self.assertEqual(frame.planes[0].buffer_size, 320)
        self.assertEqual(frame.samples, 159)

    def test_manual_s16_stereo_constructor(self) -> None:
        frame = AudioFrame(format="s16", layout="stereo", samples=160)
        self.assertEqual(frame.format.name, "s16")
        self.assertEqual(frame.layout.name, "stereo")
        self.assertEqual(len(frame.planes), 1)
        self.assertEqual(frame.planes[0].buffer_size, 640)
        self.assertEqual(frame.samples, 160)

    def test_manual_s16p_stereo_constructor(self) -> None:
        frame = AudioFrame(format="s16p", layout="stereo", samples=160)
        self.assertEqual(frame.format.name, "s16p")
        self.assertEqual(frame.layout.name, "stereo")
        self.assertEqual(len(frame.planes), 2)
        self.assertEqual(frame.planes[0].buffer_size, 320)
        self.assertEqual(frame.planes[1].buffer_size, 320)
        self.assertEqual(frame.samples, 160)


class TestAudioFrameConveniences(TestCase):
    def test_basic_to_ndarray(self) -> None:
        frame = AudioFrame(format="s16p", layout="stereo", samples=160)
        array = frame.to_ndarray()
        assert array.dtype == "i2"
        assert array.shape == (2, 160)

    def test_ndarray_dbl(self) -> None:
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
            self.assertNdarraysEqual(frame.to_ndarray(), array)

    def test_from_ndarray_value_error(self) -> None:
        # incorrect dtype
        array = np.zeros(shape=(1, 160), dtype="f2")
        with self.assertRaises(ValueError) as cm:
            AudioFrame.from_ndarray(array, format="flt", layout="mono")
        assert (
            str(cm.exception)
            == "Expected numpy array with dtype `float32` but got `float16`"
        )

        # incorrect number of dimensions
        array = np.zeros(shape=(1, 160, 2), dtype="f4")
        with self.assertRaises(ValueError) as cm:
            AudioFrame.from_ndarray(array, format="flt", layout="mono")
        assert str(cm.exception) == "Expected numpy array with ndim `2` but got `3`"

        # incorrect shape
        array = np.zeros(shape=(2, 160), dtype="f4")
        with self.assertRaises(ValueError) as cm:
            AudioFrame.from_ndarray(array, format="flt", layout="mono")
        assert str(cm.exception) == "Unexpected numpy array shape `(2, 160)`"

    def test_ndarray_flt(self) -> None:
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
            self.assertNdarraysEqual(frame.to_ndarray(), array)

    def test_ndarray_s16(self) -> None:
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
            self.assertNdarraysEqual(frame.to_ndarray(), array)

    def test_ndarray_s16p_align_8(self) -> None:
        frame = AudioFrame(format="s16p", layout="stereo", samples=159, align=8)
        array = frame.to_ndarray()
        assert array.dtype == "i2"
        assert array.shape == (2, 159)

    def test_ndarray_s32(self) -> None:
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
            self.assertNdarraysEqual(frame.to_ndarray(), array)

    def test_ndarray_u8(self) -> None:
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
            self.assertNdarraysEqual(frame.to_ndarray(), array)
