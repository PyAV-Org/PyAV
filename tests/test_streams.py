from .common import *


class TestStreams(TestCase):

    def test_stream_tuples(self):

        for fate_name in ('h264/interlaced_crop.mp4', ):

            container = av.open(fate_suite(fate_name))

            video_streams = tuple([s for s in container.streams if s.type == 'video'])
            self.assertEqual(video_streams, container.streams.video)

            audio_streams = tuple([s for s in container.streams if s.type == 'audio'])
            self.assertEqual(audio_streams, container.streams.audio)

    def test_selection(self):

        container = av.open(fate_suite('h264/interlaced_crop.mp4'))
        video = container.streams.video[0]
        #audio_stream = container.streams.audio[0]
        #audio_streams = list(container.streams.audio[0:2])

        self.assertEqual([video], container.streams.get(video=0))
        self.assertEqual([video], container.streams.get(video=(0, )))

        # TODO: Find something in the fate suite with video, audio, and subtitles.
