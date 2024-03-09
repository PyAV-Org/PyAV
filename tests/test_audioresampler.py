from fractions import Fraction

from av import AudioFrame, AudioResampler

from .common import TestCase


class TestAudioResampler(TestCase):
    def test_flush_immediately(self):
        """
        If we flush the resampler before passing any input, it returns
        a `None` frame without setting up the graph.
        """

        resampler = AudioResampler()

        # flush
        oframes = resampler.resample(None)
        self.assertEqual(len(oframes), 0)

    def test_identity_passthrough(self):
        """
        If we don't ask it to do anything, it won't.
        """

        resampler = AudioResampler()

        # resample one frame
        iframe = AudioFrame("s16", "stereo", 1024)

        oframes = resampler.resample(iframe)
        self.assertEqual(len(oframes), 1)
        self.assertIs(iframe, oframes[0])

        # resample another frame
        iframe.pts = 1024

        oframes = resampler.resample(iframe)
        self.assertEqual(len(oframes), 1)
        self.assertIs(iframe, oframes[0])

        # flush
        oframes = resampler.resample(None)
        self.assertEqual(len(oframes), 0)

    def test_matching_passthrough(self):
        """
        If the frames match, it won't do anything.
        """

        resampler = AudioResampler("s16", "stereo")

        # resample one frame
        iframe = AudioFrame("s16", "stereo", 1024)

        oframes = resampler.resample(iframe)
        self.assertEqual(len(oframes), 1)
        self.assertIs(iframe, oframes[0])

        # resample another frame
        iframe.pts = 1024

        oframes = resampler.resample(iframe)
        self.assertEqual(len(oframes), 1)
        self.assertIs(iframe, oframes[0])

        # flush
        oframes = resampler.resample(None)
        self.assertEqual(len(oframes), 0)

    def test_pts_assertion_same_rate(self):
        resampler = AudioResampler("s16", "mono")

        # resample one frame
        iframe = AudioFrame("s16", "stereo", 1024)
        iframe.sample_rate = 48000
        iframe.time_base = "1/48000"
        iframe.pts = 0

        oframes = resampler.resample(iframe)
        self.assertEqual(len(oframes), 1)

        oframe = oframes[0]
        self.assertEqual(oframe.pts, 0)
        self.assertEqual(oframe.time_base, iframe.time_base)
        self.assertEqual(oframe.sample_rate, iframe.sample_rate)
        self.assertEqual(oframe.samples, iframe.samples)

        # resample another frame
        iframe.pts = 1024

        oframes = resampler.resample(iframe)
        self.assertEqual(len(oframes), 1)

        oframe = oframes[0]
        self.assertEqual(oframe.pts, 1024)
        self.assertEqual(oframe.time_base, iframe.time_base)
        self.assertEqual(oframe.sample_rate, iframe.sample_rate)
        self.assertEqual(oframe.samples, iframe.samples)

        # resample another frame with a pts gap, do not raise exception
        iframe.pts = 9999
        oframes = resampler.resample(iframe)
        self.assertEqual(len(oframes), 1)

        oframe = oframes[0]
        self.assertEqual(oframe.pts, 9999)
        self.assertEqual(oframe.time_base, iframe.time_base)
        self.assertEqual(oframe.sample_rate, iframe.sample_rate)
        self.assertEqual(oframe.samples, iframe.samples)

        # flush
        oframes = resampler.resample(None)
        self.assertEqual(len(oframes), 0)

    def test_pts_assertion_new_rate_up(self):
        resampler = AudioResampler("s16", "mono", 44100)

        # resample one frame
        iframe = AudioFrame("s16", "stereo", 1024)
        iframe.sample_rate = 48000
        iframe.time_base = "1/48000"
        iframe.pts = 0

        oframes = resampler.resample(iframe)
        self.assertEqual(len(oframes), 1)

        oframe = oframes[0]
        self.assertEqual(oframe.pts, 0)
        self.assertEqual(oframe.time_base, Fraction(1, 44100))
        self.assertEqual(oframe.sample_rate, 44100)
        self.assertEqual(oframe.samples, 925)

        iframe = AudioFrame("s16", "stereo", 1024)
        iframe.sample_rate = 48000
        iframe.time_base = "1/48000"
        iframe.pts = 1024

        oframes = resampler.resample(iframe)
        self.assertEqual(len(oframes), 1)

        oframe = oframes[0]
        self.assertEqual(oframe.pts, 925)
        self.assertEqual(oframe.time_base, Fraction(1, 44100))
        self.assertEqual(oframe.sample_rate, 44100)
        self.assertEqual(oframe.samples, 941)

        # flush
        oframes = resampler.resample(None)
        self.assertEqual(len(oframes), 1)

        oframe = oframes[0]
        self.assertEqual(oframe.pts, 941 + 925)
        self.assertEqual(oframe.time_base, Fraction(1, 44100))
        self.assertEqual(oframe.sample_rate, 44100)
        self.assertEqual(oframe.samples, 15)

    def test_pts_assertion_new_rate_down(self):
        resampler = AudioResampler("s16", "mono", 48000)

        # resample one frame
        iframe = AudioFrame("s16", "stereo", 1024)
        iframe.sample_rate = 44100
        iframe.time_base = "1/44100"
        iframe.pts = 0

        oframes = resampler.resample(iframe)
        self.assertEqual(len(oframes), 1)

        oframe = oframes[0]
        self.assertEqual(oframe.pts, 0)
        self.assertEqual(oframe.time_base, Fraction(1, 48000))
        self.assertEqual(oframe.sample_rate, 48000)
        self.assertEqual(oframe.samples, 1098)

        iframe = AudioFrame("s16", "stereo", 1024)
        iframe.sample_rate = 44100
        iframe.time_base = "1/44100"
        iframe.pts = 1024

        oframes = resampler.resample(iframe)
        self.assertEqual(len(oframes), 1)

        oframe = oframes[0]
        self.assertEqual(oframe.pts, 1098)
        self.assertEqual(oframe.time_base, Fraction(1, 48000))
        self.assertEqual(oframe.sample_rate, 48000)
        self.assertEqual(oframe.samples, 1114)

        # flush
        oframes = resampler.resample(None)
        self.assertEqual(len(oframes), 1)

        oframe = oframes[0]
        self.assertEqual(oframe.pts, 1114 + 1098)
        self.assertEqual(oframe.time_base, Fraction(1, 48000))
        self.assertEqual(oframe.sample_rate, 48000)
        self.assertEqual(oframe.samples, 18)

    def test_pts_assertion_new_rate_fltp(self):
        resampler = AudioResampler("fltp", "mono", 8000, 1024)

        # resample one frame
        iframe = AudioFrame("s16", "mono", 1024)
        iframe.sample_rate = 8000
        iframe.time_base = "1/1000"
        iframe.pts = 0

        oframes = resampler.resample(iframe)
        self.assertEqual(len(oframes), 1)

        oframe = oframes[0]
        self.assertEqual(oframe.pts, 0)
        self.assertEqual(oframe.time_base, Fraction(1, 8000))
        self.assertEqual(oframe.sample_rate, 8000)
        self.assertEqual(oframe.samples, 1024)

        iframe = AudioFrame("s16", "mono", 1024)
        iframe.sample_rate = 8000
        iframe.time_base = "1/1000"
        iframe.pts = 8192

        oframes = resampler.resample(iframe)
        self.assertEqual(len(oframes), 1)

        oframe = oframes[0]
        self.assertEqual(oframe.pts, 65536)
        self.assertEqual(oframe.time_base, Fraction(1, 8000))
        self.assertEqual(oframe.sample_rate, 8000)
        self.assertEqual(oframe.samples, 1024)

        # flush
        oframes = resampler.resample(None)
        self.assertEqual(len(oframes), 0)

    def test_pts_missing_time_base(self):
        resampler = AudioResampler("s16", "mono", 44100)

        # resample one frame
        iframe = AudioFrame("s16", "stereo", 1024)
        iframe.sample_rate = 48000
        iframe.pts = 0

        oframes = resampler.resample(iframe)
        self.assertEqual(len(oframes), 1)

        oframe = oframes[0]
        self.assertEqual(oframe.pts, 0)
        self.assertEqual(oframe.time_base, Fraction(1, 44100))
        self.assertEqual(oframe.sample_rate, 44100)

        # flush
        oframes = resampler.resample(None)
        self.assertEqual(len(oframes), 1)

        oframe = oframes[0]
        self.assertEqual(oframe.pts, 925)
        self.assertEqual(oframe.time_base, Fraction(1, 44100))
        self.assertEqual(oframe.sample_rate, 44100)
        self.assertEqual(oframe.samples, 16)

    def test_mismatched_input(self):
        """
        Consecutive frames must have the same layout, sample format and sample rate.
        """
        resampler = AudioResampler("s16", "mono", 44100)

        # resample one frame
        iframe = AudioFrame("s16", "stereo", 1024)
        iframe.sample_rate = 48000
        resampler.resample(iframe)

        # resample another frame with a sample format
        iframe = AudioFrame("s16", "mono", 1024)
        iframe.sample_rate = 48000
        with self.assertRaises(ValueError) as cm:
            resampler.resample(iframe)
        self.assertEqual(
            str(cm.exception), "Frame does not match AudioResampler setup."
        )
