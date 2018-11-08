from av import AudioFrame, AudioResampler

from .common import TestCase


class TestAudioResampler(TestCase):

    def test_identity_passthrough(self):

        # If we don't ask it to do anything, it won't.

        resampler = AudioResampler()

        iframe = AudioFrame('s16', 'stereo', 1024)
        oframe = resampler.resample(iframe)

        self.assertIs(iframe, oframe)

    def test_matching_passthrough(self):

        # If the frames match, it won't do anything.

        resampler = AudioResampler('s16', 'stereo')

        iframe = AudioFrame('s16', 'stereo', 1024)
        oframe = resampler.resample(iframe)

        self.assertIs(iframe, oframe)

    def test_pts_assertion_same_rate(self):

        resampler = AudioResampler('s16', 'mono')

        iframe = AudioFrame('s16', 'stereo', 1024)
        iframe.sample_rate = 48000
        iframe.time_base = '1/48000'
        iframe.pts = 0

        oframe = resampler.resample(iframe)

        self.assertEqual(oframe.pts, 0)
        self.assertEqual(oframe.time_base, iframe.time_base)
        self.assertEqual(oframe.sample_rate, iframe.sample_rate)

        iframe.pts = 1024
        oframe = resampler.resample(iframe)

        self.assertEqual(oframe.pts, 1024)
        self.assertEqual(oframe.time_base, iframe.time_base)
        self.assertEqual(oframe.sample_rate, iframe.sample_rate)

        iframe.pts = 9999
        self.assertRaises(ValueError, resampler.resample, iframe)

    def test_pts_assertion_new_rate(self):

        resampler = AudioResampler('s16', 'mono', 44100)

        iframe = AudioFrame('s16', 'stereo', 1024)
        iframe.sample_rate = 48000
        iframe.time_base = '1/48000'
        iframe.pts = 0

        oframe = resampler.resample(iframe)
        self.assertEqual(oframe.pts, 0)
        self.assertEqual(str(oframe.time_base), '1/44100')
        self.assertEqual(oframe.sample_rate, 44100)

        samples_out = resampler.samples_out
        self.assertTrue(samples_out > 0)

        iframe.pts = 1024
        oframe = resampler.resample(iframe)
        self.assertEqual(oframe.pts, samples_out)
        self.assertEqual(str(oframe.time_base), '1/44100')
        self.assertEqual(oframe.sample_rate, 44100)

    def test_pts_missing_time_base(self):

        resampler = AudioResampler('s16', 'mono', 44100)

        iframe = AudioFrame('s16', 'stereo', 1024)
        iframe.sample_rate = 48000
        iframe.pts = 0

        oframe = resampler.resample(iframe)
        self.assertIs(oframe.pts, None)
        self.assertIs(oframe.time_base, None)
        self.assertEqual(oframe.sample_rate, 44100)

    def test_pts_complex_time_base(self):

        resampler = AudioResampler('s16', 'mono', 44100)

        iframe = AudioFrame('s16', 'stereo', 1024)
        iframe.sample_rate = 48000
        iframe.time_base = '1/96000'
        iframe.pts = 0

        oframe = resampler.resample(iframe)
        self.assertIs(oframe.pts, None)
        self.assertIs(oframe.time_base, None)
        self.assertEqual(oframe.sample_rate, 44100)
