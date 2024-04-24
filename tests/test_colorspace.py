import av
from av.video.reformatter import ColorRange, Colorspace

from .common import TestCase, fate_suite


class TestColorSpace(TestCase):
    def test_penguin_joke(self) -> None:
        container = av.open(
            fate_suite("amv/MTV_high_res_320x240_sample_Penguin_Joke_MTV_from_WMV.amv")
        )
        stream = container.streams.video[0]

        self.assertEqual(stream.codec_context.color_range, 2)
        self.assertEqual(stream.codec_context.color_range, ColorRange.JPEG)

        self.assertEqual(stream.codec_context.color_primaries, 2)
        self.assertEqual(stream.codec_context.color_trc, 2)

        self.assertEqual(stream.codec_context.colorspace, 5)
        self.assertEqual(stream.codec_context.colorspace, Colorspace.ITU601)

        for packet in container.demux(stream):
            for frame in packet.decode():
                assert isinstance(frame, av.VideoFrame)
                self.assertEqual(frame.color_range, ColorRange.JPEG)  # a.k.a "pc"
                self.assertEqual(frame.colorspace, Colorspace.ITU601)
                return

    def test_sky_timelapse(self) -> None:
        container = av.open(
            av.datasets.curated("pexels/time-lapse-video-of-night-sky-857195.mp4")
        )
        stream = container.streams.video[0]

        self.assertEqual(stream.codec_context.color_range, 1)
        self.assertEqual(stream.codec_context.color_range, ColorRange.MPEG)
        self.assertEqual(stream.codec_context.color_primaries, 1)
        self.assertEqual(stream.codec_context.color_trc, 1)
        self.assertEqual(stream.codec_context.colorspace, 1)
