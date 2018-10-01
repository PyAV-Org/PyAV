import warnings

from av import AudioFrame
from av.deprecation import AttributeRenamedWarning

from .common import TestCase


class TestAudioFrameConstructors(TestCase):

    def test_null_constructor(self):
        frame = AudioFrame()
        self.assertEqual(frame.format.name, 's16')
        self.assertEqual(frame.layout.name, 'stereo')
        self.assertEqual(len(frame.planes), 0)
        self.assertEqual(frame.samples, 0)

    def test_manual_s16_mono_constructor(self):
        frame = AudioFrame(format='s16', layout='mono', samples=160)
        self.assertEqual(frame.format.name, 's16')
        self.assertEqual(frame.layout.name, 'mono')
        self.assertEqual(len(frame.planes), 1)
        self.assertEqual(frame.samples, 160)

    def test_manual_s16_stereo_constructor(self):
        frame = AudioFrame(format='s16', layout='stereo', samples=160)
        self.assertEqual(frame.format.name, 's16')
        self.assertEqual(frame.layout.name, 'stereo')
        self.assertEqual(len(frame.planes), 1)
        self.assertEqual(frame.samples, 160)

    def test_manual_s16p_stereo_constructor(self):
        frame = AudioFrame(format='s16p', layout='stereo', samples=160)
        self.assertEqual(frame.format.name, 's16p')
        self.assertEqual(frame.layout.name, 'stereo')
        self.assertEqual(len(frame.planes), 2)
        self.assertEqual(frame.samples, 160)


class TestAudioFrameConveniences(TestCase):

    def test_basic_to_ndarray(self):
        frame = AudioFrame(format='s16p', layout='stereo', samples=160)
        array = frame.to_ndarray()
        self.assertEqual(array.shape, (2, 160))

    def test_basic_to_nd_array(self):
        frame = AudioFrame(format='s16p', layout='stereo', samples=160)
        with warnings.catch_warnings(record=True) as recorded:
            array = frame.to_nd_array()
        self.assertEqual(array.shape, (2, 160))

        # check deprecation warning
        self.assertEqual(len(recorded), 1)
        self.assertEqual(recorded[0].category, AttributeRenamedWarning)
        self.assertEqual(
            str(recorded[0].message),
            'AudioFrame.to_nd_array is deprecated; please use AudioFrame.to_ndarray.')
