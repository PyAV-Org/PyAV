import av

from .common import TestCase, fate_suite


class TestStreams(TestCase):
    def test_stream_tuples(self):
        for fate_name in ("h264/interlaced_crop.mp4",):
            container = av.open(fate_suite(fate_name))

            video_streams = tuple([s for s in container.streams if s.type == "video"])
            self.assertEqual(video_streams, container.streams.video)

            audio_streams = tuple([s for s in container.streams if s.type == "audio"])
            self.assertEqual(audio_streams, container.streams.audio)

    def test_selection(self) -> None:
        container = av.open(
            fate_suite("amv/MTV_high_res_320x240_sample_Penguin_Joke_MTV_from_WMV.amv")
        )
        video = container.streams.video[0]
        audio = container.streams.audio[0]

        self.assertEqual([video], container.streams.get(video=0))
        self.assertEqual([video], container.streams.get(video=(0,)))

        self.assertEqual(video, container.streams.best("video"))
        self.assertEqual(audio, container.streams.best("audio"))

        container = av.open(fate_suite("sub/MovText_capability_tester.mp4"))
        subtitle = container.streams.subtitles[0]
        self.assertEqual(subtitle, container.streams.best("subtitle"))

        container = av.open(fate_suite("mxf/track_01_v02.mxf"))
        data = container.streams.data[0]
        self.assertEqual(data, container.streams.best("data"))

    def test_noside_data(self):
        container = av.open(fate_suite("h264/interlaced_crop.mp4"))
        video = container.streams.video[0]

        self.assertEqual(video.nb_side_data, 0)

    def test_side_data(self):
        container = av.open(fate_suite("mov/displaymatrix.mov"))
        video = container.streams.video[0]

        self.assertEqual(video.nb_side_data, 1)
        self.assertEqual(video.side_data["DISPLAYMATRIX"], -90.0)
