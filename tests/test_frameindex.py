import av

from .common import TestCase, fate_suite


class TestFrameIndex(TestCase):
    def test_frame_index_len_mp4(self) -> None:
        with av.open(fate_suite("h264/interlaced_crop.mp4")) as container:
            stream = container.streams.video[0]
            assert len(stream.frame_index) == stream.frames

    def test_frame_index_len_webm(self) -> None:
        with av.open(
            fate_suite("vp9-test-vectors/vp90-2-00-quantizer-00.webm")
        ) as container:
            stream = container.streams.video[0]
            frame_index_len_before_demux = len(stream.frame_index)

            keyframes = len([p for p in container.demux(video=0) if p.is_keyframe])
            assert frame_index_len_before_demux == keyframes

    def test_frame_index_search_timestamp_options_mp4(self) -> None:
        with av.open(fate_suite("h264/interlaced_crop.mp4")) as container:
            stream = container.streams.video[0]
            fi = stream.frame_index

            target_ts = -1

            assert fi.search_timestamp(target_ts) == 0
            assert fi.search_timestamp(target_ts, any_frame=True) == 1
            assert fi.search_timestamp(target_ts, backward=False) == 21
            assert fi.search_timestamp(target_ts, backward=False, any_frame=True) == 1

            e0 = fi[0]
            e1 = fi[1]
            e21 = fi[21]
            assert e0 is not None and e0.timestamp == -2 and e0.is_keyframe
            assert e1 is not None and e1.timestamp == -1 and not e1.is_keyframe
            assert e21 is not None and e21.timestamp == 19 and e21.is_keyframe

    def test_frame_index_matches_packet_mp4(self) -> None:
        with av.open(fate_suite("h264/interlaced_crop.mp4")) as container:
            stream = container.streams.video[0]
            for i, packet in enumerate(container.demux(video=0)):
                if packet.dts is not None:
                    entry = stream.frame_index[i]
                    assert entry is not None
                    assert entry.timestamp == packet.dts

    def test_frame_index_in_bounds(self) -> None:
        with av.open(fate_suite("h264/interlaced_crop.mp4")) as container:
            stream = container.streams.video[0]
            first = stream.frame_index[0]
            first_neg = stream.frame_index[-len(stream.frame_index)]
            last = stream.frame_index[-1]
            last_pos = stream.frame_index[len(stream.frame_index) - 1]
            assert first is not None
            assert first_neg is not None
            assert last is not None
            assert last_pos is not None
            assert first.timestamp == first_neg.timestamp
            assert last.timestamp == last_pos.timestamp

    def test_frame_index_out_of_bounds(self) -> None:
        with av.open(fate_suite("h264/interlaced_crop.mp4")) as container:
            stream = container.streams.video[0]
            with self.assertRaises(IndexError):
                _ = stream.frame_index[len(stream.frame_index)]

            with self.assertRaises(IndexError):
                _ = stream.frame_index[-len(stream.frame_index) - 1]

    def test_frame_index_slice(self) -> None:
        with av.open(fate_suite("h264/interlaced_crop.mp4")) as container:
            stream = container.streams.video[0]

            individual_indices = [stream.frame_index[i] for i in range(1,5)]
            slice_indices = stream.frame_index[1:5]
            assert len(individual_indices) == len(slice_indices) == 4
            assert all(entry is not None for entry in individual_indices)
            assert all(entry is not None for entry in slice_indices)
            assert all([
                i.timestamp == j.timestamp
                for i, j in zip(individual_indices, slice_indices)
                if i is not None and j is not None
            ])
