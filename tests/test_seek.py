import av

from .common import TestCase, fate_suite


def timestamp_to_frame(timestamp: int, stream: av.video.stream.VideoStream) -> float:
    fps = stream.average_rate
    time_base = stream.time_base
    start_time = stream.start_time
    assert time_base is not None and start_time is not None and fps is not None
    return (timestamp - start_time) * float(time_base) * float(fps)


class TestSeek(TestCase):
    def test_seek_float(self) -> None:
        container = av.open(fate_suite("h264/interlaced_crop.mp4"))
        self.assertRaises(TypeError, container.seek, 1.0)

    def test_seek_int64(self) -> None:
        # Assert that it accepts large values.
        # Issue 251 pointed this out.
        container = av.open(fate_suite("h264/interlaced_crop.mp4"))
        container.seek(2**32)

    def test_seek_start(self) -> None:
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

        assert total_packet_count == seek_packet_count

    def test_seek_middle(self) -> None:
        container = av.open(fate_suite("h264/interlaced_crop.mp4"))
        assert container.duration is not None

        # count all the packets
        total_packet_count = 0
        for packet in container.demux():
            total_packet_count += 1

        # seek to middle
        container.seek(container.duration // 2)

        seek_packet_count = 0
        for packet in container.demux():
            seek_packet_count += 1

        assert seek_packet_count < total_packet_count

    def test_seek_end(self) -> None:
        container = av.open(fate_suite("h264/interlaced_crop.mp4"))
        assert container.duration is not None

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
        assert seek_packet_count > 0
        assert seek_packet_count < middle_packet_count

    def test_decode_half(self) -> None:
        container = av.open(fate_suite("h264/interlaced_crop.mp4"))
        video_stream = container.streams.video[0]

        total_frame_count = 0
        for frame in container.decode(video_stream):
            total_frame_count += 1

        assert video_stream.frames == total_frame_count
        assert video_stream.average_rate is not None

        # set target frame to middle frame
        target_frame = total_frame_count // 2
        target_timestamp = int(
            (target_frame * av.time_base) / video_stream.average_rate
        )

        # should seek to nearest keyframe before target_timestamp
        container.seek(target_timestamp)

        current_frame = None
        frame_count = 0

        for frame in container.decode(video_stream):
            if current_frame is None:
                current_frame = timestamp_to_frame(frame.pts, video_stream)
            else:
                current_frame += 1

            # start counting once we reach the target frame
            if current_frame is not None and current_frame >= target_frame:
                frame_count += 1

        assert frame_count == total_frame_count - target_frame

    def test_stream_seek(self) -> None:
        container = av.open(fate_suite("h264/interlaced_crop.mp4"))
        video_stream = container.streams.video[0]

        assert video_stream.time_base is not None
        assert video_stream.start_time is not None
        assert video_stream.average_rate is not None

        total_frame_count = 0
        for frame in container.decode(video_stream):
            total_frame_count += 1

        target_frame = total_frame_count // 2
        time_base = float(video_stream.time_base)
        target_sec = target_frame * 1 / float(video_stream.average_rate)

        target_timestamp = int(target_sec / time_base) + video_stream.start_time
        container.seek(target_timestamp, stream=video_stream)

        current_frame = None
        frame_count = 0

        for frame in container.decode(video_stream):
            if current_frame is None:
                assert frame.pts is not None
                current_frame = timestamp_to_frame(frame.pts, video_stream)
            else:
                current_frame += 1

            # start counting once we reach the target frame
            if current_frame is not None and current_frame >= target_frame:
                frame_count += 1

        assert frame_count == total_frame_count - target_frame
