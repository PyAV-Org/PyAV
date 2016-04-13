from __future__ import print_function
from .common import *


class TestDecode(TestCase):
    def test_decoded_video_frame_count(self):
        
        container = av.open(fate_suite('h264/interlaced_crop.mp4'))
        video_stream = next(s for s in container.streams if s.type == 'video')

        self.assertIs(video_stream, container.streams.video[0])

        frame_count = 0
        
        for packet in container.demux(video_stream):
            for frame in packet.decode():
                frame_count += 1
                        
        self.assertEqual(frame_count, video_stream.frames)
        
    def test_decode_audio_sample_count(self):
        container = av.open(fate_suite('audio-reference/chorusnoise_2ch_44kHz_s16.wav'))
        audio_stream = next(s for s in container.streams if s.type == 'audio')
        
        self.assertIs(audio_stream, container.streams.audio[0])
        
        sample_count = 0
        
        print(audio_stream.frames)
        for packet in container.demux(audio_stream):
            for frame in packet.decode():
                sample_count += frame.samples
        
        total_samples = (audio_stream.duration * audio_stream.rate.numerator) / audio_stream.time_base.denominator
        self.assertEqual(sample_count, total_samples)
