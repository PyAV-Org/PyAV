import av
from fractions import Fraction

from .common import TestCase, fate_suite


class TestStreams(TestCase):
    def test_stream_tuples(self):

        for fate_name in ("h264/interlaced_crop.mp4",):

            container = av.open(fate_suite(fate_name))

            video_streams = tuple([s for s in container.streams if s.type == "video"])
            self.assertEqual(video_streams, container.streams.video)

            audio_streams = tuple([s for s in container.streams if s.type == "audio"])
            self.assertEqual(audio_streams, container.streams.audio)

    def test_selection(self):

        container = av.open(fate_suite("h264/interlaced_crop.mp4"))
        video = container.streams.video[0]
        # audio_stream = container.streams.audio[0]
        # audio_streams = list(container.streams.audio[0:2])

        self.assertEqual([video], container.streams.get(video=0))
        self.assertEqual([video], container.streams.get(video=(0,)))

        # TODO: Find something in the fate suite with video, audio, and subtitles.

    def test_stream_properties(self):
        # Ensure that all stream properties have sensible values even
        # if writing to the stream hasn't started yet
        with av.open(self.sandboxed("output.mp4"), "w") as container:
            stream = container.add_stream('h264')
            assert stream.id is not None
            assert stream.profile is None
            assert stream.index == 0
            assert stream.time_base is None
            assert stream.average_rate == Fraction(24, 1)
            assert stream.base_rate is None
            assert stream.guessed_rate is None
            assert stream.start_time is None
            assert stream.duration is None
            assert stream.frames == 0
            assert stream.language is None
            assert stream.type is None
