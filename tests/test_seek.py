import unittest

import av

from .common import TestCase, fate_suite


def timestamp_to_frame(timestamp, stream):
    fps = stream.average_rate
    time_base = stream.time_base
    start_time = stream.start_time
    frame = (timestamp - start_time) * float(time_base) * float(fps)
    return frame


def step_forward(container, stream):
    for packet in container.demux(stream):
        for frame in packet.decode():
            if frame:
                return frame


class TestSeek(TestCase):
    def test_seek_float(self):
        container = av.open(fate_suite("h264/interlaced_crop.mp4"))
        self.assertRaises(TypeError, container.seek, 1.0)

    def test_seek_int64(self):
        # Assert that it accepts large values.
        # Issue 251 pointed this out.
        container = av.open(fate_suite("h264/interlaced_crop.mp4"))
        container.seek(2**32)

    def test_seek_start(self):
        container = av.open(fate_suite("h264/interlaced_crop.mp4"))

        # count all the packets
        total_packet_count = 0
        for packet in container.demux():
            total_packet_count += 1

        # seek to beginning
        container.seek(-1)

        # count packets again
        seek_packet_count = 0
        for packet in container.demux():
            seek_packet_count += 1

        self.assertEqual(total_packet_count, seek_packet_count)

    def test_seek_middle(self):
        container = av.open(fate_suite("h264/interlaced_crop.mp4"))

        # count all the packets
        total_packet_count = 0
        for packet in container.demux():
            total_packet_count += 1

        # seek to middle
        container.seek(container.duration // 2)

        seek_packet_count = 0
        for packet in container.demux():
            seek_packet_count += 1

        self.assertTrue(seek_packet_count < total_packet_count)

    def test_seek_end(self):
        container = av.open(fate_suite("h264/interlaced_crop.mp4"))

        # seek to middle
        container.seek(container.duration // 2)
        middle_packet_count = 0

        for packet in container.demux():
            middle_packet_count += 1

        # you can't really seek to to end but you can to the last keyframe
        container.seek(container.duration)

        seek_packet_count = 0
        for packet in container.demux():
            seek_packet_count += 1

        # there should be some packet because we're seeking to the last keyframe
        self.assertTrue(seek_packet_count > 0)
        self.assertTrue(seek_packet_count < middle_packet_count)

    def test_decode_half(self):

        container = av.open(fate_suite("h264/interlaced_crop.mp4"))

        video_stream = next(s for s in container.streams if s.type == "video")
        total_frame_count = 0

        # Count number of frames in video
        for packet in container.demux(video_stream):
            for frame in packet.decode():
                total_frame_count += 1

        self.assertEqual(video_stream.frames, total_frame_count)

        # set target frame to middle frame
        target_frame = int(total_frame_count / 2.0)
        target_timestamp = int(
            (target_frame * av.time_base) / video_stream.average_rate
        )

        # should seek to nearest keyframe before target_timestamp
        container.seek(target_timestamp)

        current_frame = None
        frame_count = 0

        for packet in container.demux(video_stream):
            for frame in packet.decode():
                if current_frame is None:
                    current_frame = timestamp_to_frame(frame.pts, video_stream)
                else:
                    current_frame += 1

                # start counting once we reach the target frame
                if current_frame is not None and current_frame >= target_frame:
                    frame_count += 1

        self.assertEqual(frame_count, total_frame_count - target_frame)

    def test_stream_seek(self):

        container = av.open(fate_suite("h264/interlaced_crop.mp4"))

        video_stream = next(s for s in container.streams if s.type == "video")
        total_frame_count = 0

        # Count number of frames in video
        for packet in container.demux(video_stream):
            for frame in packet.decode():
                total_frame_count += 1

        target_frame = int(total_frame_count / 2.0)
        time_base = float(video_stream.time_base)

        rate = float(video_stream.average_rate)
        target_sec = target_frame * 1 / rate

        target_timestamp = int(target_sec / time_base) + video_stream.start_time
        container.seek(target_timestamp, stream=video_stream)

        current_frame = None
        frame_count = 0

        for packet in container.demux(video_stream):
            for frame in packet.decode():
                if current_frame is None:
                    current_frame = timestamp_to_frame(frame.pts, video_stream)

                else:
                    current_frame += 1

                # start counting once we reach the target frame
                if current_frame is not None and current_frame >= target_frame:
                    frame_count += 1

        self.assertEqual(frame_count, total_frame_count - target_frame)


if __name__ == "__main__":
    unittest.main()
