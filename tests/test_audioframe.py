import numpy

from av import AudioFrame

from .common import TestCase


class TestAudioFrameConstructors(TestCase):
    def test_null_constructor(self):
        frame = AudioFrame()
        self.assertEqual(frame.format.name, "s16")
        self.assertEqual(frame.layout.name, "stereo")
        self.assertEqual(len(frame.planes), 0)
        self.assertEqual(frame.samples, 0)

    def test_manual_flt_mono_constructor(self):
        frame = AudioFrame(format="flt", layout="mono", samples=160)
        self.assertEqual(frame.format.name, "flt")
        self.assertEqual(frame.layout.name, "mono")
        self.assertEqual(len(frame.planes), 1)
        self.assertEqual(frame.planes[0].buffer_size, 640)
        self.assertEqual(frame.samples, 160)

    def test_manual_flt_stereo_constructor(self):
        frame = AudioFrame(format="flt", layout="stereo", samples=160)
        self.assertEqual(frame.format.name, "flt")
        self.assertEqual(frame.layout.name, "stereo")
        self.assertEqual(len(frame.planes), 1)
        self.assertEqual(frame.planes[0].buffer_size, 1280)
        self.assertEqual(frame.samples, 160)

    def test_manual_fltp_stereo_constructor(self):
        frame = AudioFrame(format="fltp", layout="stereo", samples=160)
        self.assertEqual(frame.format.name, "fltp")
        self.assertEqual(frame.layout.name, "stereo")
        self.assertEqual(len(frame.planes), 2)
        self.assertEqual(frame.planes[0].buffer_size, 640)
        self.assertEqual(frame.planes[1].buffer_size, 640)
        self.assertEqual(frame.samples, 160)

    def test_manual_s16_mono_constructor(self):
        frame = AudioFrame(format="s16", layout="mono", samples=160)
        self.assertEqual(frame.format.name, "s16")
        self.assertEqual(frame.layout.name, "mono")
        self.assertEqual(len(frame.planes), 1)
        self.assertEqual(frame.planes[0].buffer_size, 320)
        self.assertEqual(frame.samples, 160)

    def test_manual_s16_mono_constructor_align_8(self):
        frame = AudioFrame(format="s16", layout="mono", samples=159, align=8)
        self.assertEqual(frame.format.name, "s16")
        self.assertEqual(frame.layout.name, "mono")
        self.assertEqual(len(frame.planes), 1)
        self.assertEqual(frame.planes[0].buffer_size, 320)
        self.assertEqual(frame.samples, 159)

    def test_manual_s16_stereo_constructor(self):
        frame = AudioFrame(format="s16", layout="stereo", samples=160)
        self.assertEqual(frame.format.name, "s16")
        self.assertEqual(frame.layout.name, "stereo")
        self.assertEqual(len(frame.planes), 1)
        self.assertEqual(frame.planes[0].buffer_size, 640)
        self.assertEqual(frame.samples, 160)

    def test_manual_s16p_stereo_constructor(self):
        frame = AudioFrame(format="s16p", layout="stereo", samples=160)
        self.assertEqual(frame.format.name, "s16p")
        self.assertEqual(frame.layout.name, "stereo")
        self.assertEqual(len(frame.planes), 2)
        self.assertEqual(frame.planes[0].buffer_size, 320)
        self.assertEqual(frame.planes[1].buffer_size, 320)
        self.assertEqual(frame.samples, 160)


class TestAudioFrameConveniences(TestCase):
    def test_basic_to_ndarray(self):
        frame = AudioFrame(format="s16p", layout="stereo", samples=160)
        array = frame.to_ndarray()
        self.assertEqual(array.dtype, "i2")
        self.assertEqual(array.shape, (2, 160))

    def test_ndarray_dbl(self):
        layouts = [
            ("dbl", "mono", "f8", (1, 160)),
            ("dbl", "stereo", "f8", (1, 320)),
            ("dblp", "mono", "f8", (1, 160)),
            ("dblp", "stereo", "f8", (2, 160)),
        ]
        for format, layout, dtype, size in layouts:
            array = numpy.ndarray(shape=size, dtype=dtype)
            for i in range(size[0]):
                array[i][:] = numpy.random.rand(size[1])
            frame = AudioFrame.from_ndarray(array, format=format, layout=layout)
            self.assertEqual(frame.format.name, format)
            self.assertEqual(frame.layout.name, layout)
            self.assertEqual(frame.samples, 160)
            self.assertNdarraysEqual(frame.to_ndarray(), array)

    def test_from_ndarray_value_error(self):
        # incorrect dtype
        array = numpy.ndarray(shape=(1, 160), dtype="f2")
        with self.assertRaises(ValueError) as cm:
            AudioFrame.from_ndarray(array, format="flt", layout="mono")
        self.assertEqual(
            str(cm.exception),
            "Expected numpy array with dtype `float32` but got `float16`",
        )

        # incorrect number of dimensions
        array = numpy.ndarray(shape=(1, 160, 2), dtype="f4")
        with self.assertRaises(ValueError) as cm:
            AudioFrame.from_ndarray(array, format="flt", layout="mono")
        self.assertEqual(
            str(cm.exception), "Expected numpy array with ndim `2` but got `3`"
        )

        # incorrect shape
        array = numpy.ndarray(shape=(2, 160), dtype="f4")
        with self.assertRaises(ValueError) as cm:
            AudioFrame.from_ndarray(array, format="flt", layout="mono")
        self.assertEqual(str(cm.exception), "Unexpected numpy array shape `(2, 160)`")

    def test_ndarray_flt(self):
        layouts = [
            ("flt", "mono", "f4", (1, 160)),
            ("flt", "stereo", "f4", (1, 320)),
            ("fltp", "mono", "f4", (1, 160)),
            ("fltp", "stereo", "f4", (2, 160)),
        ]
        for format, layout, dtype, size in layouts:
            array = numpy.ndarray(shape=size, dtype=dtype)
            for i in range(size[0]):
                array[i][:] = numpy.random.rand(size[1])
            frame = AudioFrame.from_ndarray(array, format=format, layout=layout)
            self.assertEqual(frame.format.name, format)
            self.assertEqual(frame.layout.name, layout)
            self.assertEqual(frame.samples, 160)
            self.assertNdarraysEqual(frame.to_ndarray(), array)

    def test_ndarray_s16(self):
        layouts = [
            ("s16", "mono", "i2", (1, 160)),
            ("s16", "stereo", "i2", (1, 320)),
            ("s16p", "mono", "i2", (1, 160)),
            ("s16p", "stereo", "i2", (2, 160)),
        ]
        for format, layout, dtype, size in layouts:
            array = numpy.random.randint(0, 256, size=size, dtype=dtype)
            frame = AudioFrame.from_ndarray(array, format=format, layout=layout)
            self.assertEqual(frame.format.name, format)
            self.assertEqual(frame.layout.name, layout)
            self.assertEqual(frame.samples, 160)
            self.assertNdarraysEqual(frame.to_ndarray(), array)

    def test_ndarray_s16p_align_8(self):
        frame = AudioFrame(format="s16p", layout="stereo", samples=159, align=8)
        array = frame.to_ndarray()
        self.assertEqual(array.dtype, "i2")
        self.assertEqual(array.shape, (2, 159))

    def test_ndarray_s32(self):
        layouts = [
            ("s32", "mono", "i4", (1, 160)),
            ("s32", "stereo", "i4", (1, 320)),
            ("s32p", "mono", "i4", (1, 160)),
            ("s32p", "stereo", "i4", (2, 160)),
        ]
        for format, layout, dtype, size in layouts:
            array = numpy.random.randint(0, 256, size=size, dtype=dtype)
            frame = AudioFrame.from_ndarray(array, format=format, layout=layout)
            self.assertEqual(frame.format.name, format)
            self.assertEqual(frame.layout.name, layout)
            self.assertEqual(frame.samples, 160)
            self.assertNdarraysEqual(frame.to_ndarray(), array)

    def test_ndarray_u8(self):
        layouts = [
            ("u8", "mono", "u1", (1, 160)),
            ("u8", "stereo", "u1", (1, 320)),
            ("u8p", "mono", "u1", (1, 160)),
            ("u8p", "stereo", "u1", (2, 160)),
        ]
        for format, layout, dtype, size in layouts:
            array = numpy.random.randint(0, 256, size=size, dtype=dtype)
            frame = AudioFrame.from_ndarray(array, format=format, layout=layout)
            self.assertEqual(frame.format.name, format)
            self.assertEqual(frame.layout.name, layout)
            self.assertEqual(frame.samples, 160)
            self.assertNdarraysEqual(frame.to_ndarray(), array)
