import av

from .common import TestCase, fate_suite


class TestDecode(TestCase):
    def test_decoded_video_frame_count(self):

        container = av.open(fate_suite("h264/interlaced_crop.mp4"))
        video_stream = next(s for s in container.streams if s.type == "video")

        self.assertIs(video_stream, container.streams.video[0])

        frame_count = 0

        for packet in container.demux(video_stream):
            for frame in packet.decode():
                frame_count += 1

        self.assertEqual(frame_count, video_stream.frames)

    def test_decode_audio_sample_count(self):

        container = av.open(fate_suite("audio-reference/chorusnoise_2ch_44kHz_s16.wav"))
        audio_stream = next(s for s in container.streams if s.type == "audio")

        self.assertIs(audio_stream, container.streams.audio[0])

        sample_count = 0

        for packet in container.demux(audio_stream):
            for frame in packet.decode():
                sample_count += frame.samples

        total_samples = (
            audio_stream.duration * audio_stream.rate.numerator
        ) / audio_stream.time_base.denominator
        self.assertEqual(sample_count, total_samples)

    def test_decoded_time_base(self):

        container = av.open(fate_suite("h264/interlaced_crop.mp4"))
        stream = container.streams.video[0]
        codec_context = stream.codec_context

        self.assertNotEqual(stream.time_base, codec_context.time_base)

        for packet in container.demux(stream):
            for frame in packet.decode():
                self.assertEqual(packet.time_base, frame.time_base)
                self.assertEqual(stream.time_base, frame.time_base)
                return

    def test_decoded_motion_vectors(self):

        container = av.open(fate_suite("h264/interlaced_crop.mp4"))
        stream = container.streams.video[0]
        codec_context = stream.codec_context
        codec_context.options = {"flags2": "+export_mvs"}

        for packet in container.demux(stream):
            for frame in packet.decode():
                vectors = frame.side_data.get("MOTION_VECTORS")
                if frame.key_frame:
                    # Key frame don't have motion vectors
                    assert vectors is None
                else:
                    assert len(vectors) > 0
                    return

    def test_decoded_motion_vectors_no_flag(self):

        container = av.open(fate_suite("h264/interlaced_crop.mp4"))
        stream = container.streams.video[0]

        for packet in container.demux(stream):
            for frame in packet.decode():
                vectors = frame.side_data.get("MOTION_VECTORS")
                if not frame.key_frame:
                    assert vectors is None
                    return
